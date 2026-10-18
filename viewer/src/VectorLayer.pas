unit VectorLayer;

interface

uses
  SysUtils,
  System.Generics.Collections,
  System.UITypes,
  gdalcore,
  ogr,
  GeometryModel;

type
  EVectorLayerError = class(Exception);

  TStringArray = array of string;
  TAttributeRowEvent = function(const Values: TStringArray): Boolean of object;
  TLoadProgressEvent = procedure(const LayerName: string;
    Current, Total: Integer) of object;

  {
    Dueño compartido de un OGRDataSourceH. Varias TVectorLayer de un mismo
    archivo comparten el datasource; se cierra cuando la última capa lo libera.
  }
  TDataSourceOwner = class
  private
    FHandle: OGRDataSourceH;
    FRefCount: Integer;
  public
    constructor Create(AHandle: OGRDataSourceH);
    destructor Destroy; override;
    procedure AddRef;
    procedure Release;
    property Handle: OGRDataSourceH read FHandle;
  end;

  {
    Abre un archivo vectorial con OGR, extrae las entidades a un modelo en
    memoria (GeometryModel) y conserva el datasource/layer abiertos para leer
    atributos e identificar sin reabrir.
  }
  TVectorLayer = class
  private
    FFileName: string;
    FLayerName: string;
    FFeatures: TFeatureArray;
    FExtent: TExtent;
    FFieldCount: Integer;
    FFieldNames: TStringArray;
    FLayerIndex: Integer;
    FProgress: TLoadProgressEvent;
    FVisible: Boolean;
    FFillEnabled: Boolean;
    FFillColor: TColor;
    FLineColor: TColor;
    FLineWidth: Integer;
    FOwner: TDataSourceOwner;
    FLayer: OGRLayerH;
    FFidToIndex: TDictionary<Int64, Integer>;
    procedure ExtractRing(geom: OGRGeometryH; var Ring: TPointArray);
    function GeometryToModel(geom: OGRGeometryH): TFeatureGeometry;
    procedure ExtractLayer(layer: OGRLayerH);
    function GetDataSource: OGRDataSourceH;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load(const FileName: string;
      Progress: TLoadProgressEvent = nil);
    procedure Clear;
    class function LoadLayers(const FileName: string;
      Progress: TLoadProgressEvent = nil): TArray<TVectorLayer>;
    function GetFeatureAttributes(FeatureIndex: Integer;
      out Names, Values: TStringArray): Boolean;
    procedure ForEachAttributeRow(const Callback: TAttributeRowEvent);
    function IdentifyAtWorld(const P: TPointD; Tolerance: Double): Integer;

    property FileName: string read FFileName;
    property DataSource: OGRDataSourceH read GetDataSource;
    property OgrLayer: OGRLayerH read FLayer;
    property LayerIndex: Integer read FLayerIndex;
    property LayerName: string read FLayerName;
    property Features: TFeatureArray read FFeatures;
    property Extent: TExtent read FExtent;
    property FieldCount: Integer read FFieldCount;
    property FieldNames: TStringArray read FFieldNames;
    property Visible: Boolean read FVisible write FVisible;
    property FillEnabled: Boolean read FFillEnabled write FFillEnabled;
    property FillColor: TColor read FFillColor write FFillColor;
    property LineColor: TColor read FLineColor write FLineColor;
    property LineWidth: Integer read FLineWidth write FLineWidth;
    function FeatureCount: Integer;
  end;

implementation

{ TDataSourceOwner }

constructor TDataSourceOwner.Create(AHandle: OGRDataSourceH);
begin
  inherited Create;
  FHandle := AHandle;
  FRefCount := 0;
end;

destructor TDataSourceOwner.Destroy;
begin
  if FHandle <> nil then
    OGRReleaseDataSource(FHandle);
  inherited Destroy;
end;

procedure TDataSourceOwner.AddRef;
begin
  Inc(FRefCount);
end;

procedure TDataSourceOwner.Release;
begin
  Dec(FRefCount);
  if FRefCount <= 0 then
    Free;
end;

constructor TVectorLayer.Create;
begin
  inherited Create;
  FVisible := True;
  FFillEnabled := True;
  FFillColor := $FAEA8F00;   // azul (BGR)
  FLineColor := $F4D10B00;   // azul #
  FLineWidth := 1;
  ExtentReset(FExtent);
end;

destructor TVectorLayer.Destroy;
begin
  FFidToIndex.Free;
  if FOwner <> nil then
    FOwner.Release;
  inherited Destroy;
end;

procedure TVectorLayer.Clear;
begin
  FFidToIndex.Free;
  FFidToIndex := nil;
  if FOwner <> nil then
    FOwner.Release;
  FOwner := nil;
  FLayer := nil;
  FFeatures := nil;
  FLayerName := '';
  FFileName := '';
  FFieldCount := 0;
  FFieldNames := nil;
  FLayerIndex := 0;
  ExtentReset(FExtent);
end;

function TVectorLayer.FeatureCount: Integer;
begin
  Result := Length(FFeatures);
end;

function TVectorLayer.GetDataSource: OGRDataSourceH;
begin
  if FOwner <> nil then
    Result := FOwner.Handle
  else
    Result := nil;
end;

procedure TVectorLayer.ExtractRing(geom: OGRGeometryH; var Ring: TPointArray);
var
  n, i: Integer;
begin
  n := OGR_G_GetPointCount(geom);
  SetLength(Ring, n);
  for i := 0 to n - 1 do
    Ring[i] := MakePoint(OGR_G_GetX(geom, i), OGR_G_GetY(geom, i));
end;

function TVectorLayer.GeometryToModel(geom: OGRGeometryH): TFeatureGeometry;
var
  t: OGRwkbGeometryType;
  flat, n, i: Integer;
begin
  if geom = nil then
    Exit;

  t := OGR_G_GetGeometryType(geom);
  flat := Integer(Ord(t)) and $7FFFFFFF;   // wkbFlatten

  case flat of
    1: begin   // wkbPoint
      Result.Kind := gkPoint;
      SetLength(Result.Points, 1);
      Result.Points[0] := MakePoint(OGR_G_GetX(geom, 0), OGR_G_GetY(geom, 0));
    end;

    2: begin   // wkbLineString
      Result.Kind := gkLineString;
      n := OGR_G_GetPointCount(geom);
      SetLength(Result.Points, n);
      for i := 0 to n - 1 do
        Result.Points[i] := MakePoint(OGR_G_GetX(geom, i), OGR_G_GetY(geom, i));
    end;

    3: begin   // wkbPolygon
      Result.Kind := gkPolygon;
      n := OGR_G_GetGeometryCount(geom);   // nº de anillos
      SetLength(Result.Rings, n);
      for i := 0 to n - 1 do
        ExtractRing(OGR_G_GetGeometryRef(geom, i), Result.Rings[i]);
    end;

    4: begin   // wkbMultiPoint
      Result.Kind := gkMultiPoint;
      n := OGR_G_GetGeometryCount(geom);
      SetLength(Result.Parts, n);
      for i := 0 to n - 1 do
        Result.Parts[i] := GeometryToModel(OGR_G_GetGeometryRef(geom, i));
    end;

    5: begin   // wkbMultiLineString
      Result.Kind := gkMultiLineString;
      n := OGR_G_GetGeometryCount(geom);
      SetLength(Result.Parts, n);
      for i := 0 to n - 1 do
        Result.Parts[i] := GeometryToModel(OGR_G_GetGeometryRef(geom, i));
    end;

    6: begin   // wkbMultiPolygon
      Result.Kind := gkMultiPolygon;
      n := OGR_G_GetGeometryCount(geom);
      SetLength(Result.Parts, n);
      for i := 0 to n - 1 do
        Result.Parts[i] := GeometryToModel(OGR_G_GetGeometryRef(geom, i));
    end;

  else
    { wkbGeometryCollection, wkbUnknown u otros: contenedor genérico. }
    Result.Kind := gkMultiPolygon;
    n := OGR_G_GetGeometryCount(geom);
    SetLength(Result.Parts, n);
    for i := 0 to n - 1 do
      Result.Parts[i] := GeometryToModel(OGR_G_GetGeometryRef(geom, i));
  end;
end;

procedure TVectorLayer.ExtractLayer(layer: OGRLayerH);
var
  featDefn: OGRFeatureDefnH;
  feat: OGRFeatureH;
  fldDefn: OGRFieldDefnH;
  fieldCount, i, n, count: Integer;
  featRec: TFeature;
begin
  featDefn := OGR_L_GetLayerDefn(layer);
  fieldCount := OGR_FD_GetFieldCount(featDefn);
  FFieldCount := fieldCount;
  FLayerName := UTF8ToString(OGR_L_GetName(layer));

  SetLength(FFieldNames, fieldCount);
  for i := 0 to fieldCount - 1 do begin
    fldDefn := OGR_FD_GetFieldDefn(featDefn, i);
    FFieldNames[i] := UTF8ToString(OGR_Fld_GetNameRef(fldDefn));
  end;

  count := OGR_L_GetFeatureCount(layer, 0);
  if count < 0 then
    count := 0;
  SetLength(FFeatures, count);
  n := 0;

  if FFidToIndex = nil then
    FFidToIndex := TDictionary<Int64, Integer>.Create
  else
    FFidToIndex.Clear;

  ExtentReset(FExtent);

  OGR_L_ResetReading(layer);
  feat := OGR_L_GetNextFeature(layer);
  while feat <> nil do begin
    if n >= Length(FFeatures) then
      SetLength(FFeatures, n + 1024);

    featRec.FID := OGR_F_GetFID(feat);
    featRec.Geometry := GeometryToModel(OGR_F_GetGeometryRef(feat));
    GeometryExtent(featRec.Geometry, FExtent);

    FFeatures[n] := featRec;
    FFidToIndex.AddOrSetValue(featRec.FID, n);
    Inc(n);

    if Assigned(FProgress) and ((n mod 5000) = 0) then
      FProgress(FLayerName, n, count);

    OGR_F_Destroy(feat);
    feat := OGR_L_GetNextFeature(layer);
  end;
  SetLength(FFeatures, n);

  if Assigned(FProgress) then begin
    if count > 0 then
      FProgress(FLayerName, n, count)
    else
      FProgress(FLayerName, n, n);
  end;
end;

procedure TVectorLayer.Load(const FileName: string;
  Progress: TLoadProgressEvent);
var
  utf8: UTF8String;
  ds: OGRDataSourceH;
  layer: OGRLayerH;
  owner: TDataSourceOwner;
begin
  Clear;
  FFileName := FileName;
  FLayerIndex := 0;
  FProgress := Progress;

  OGRRegisterAll;
  utf8 := UTF8String(FileName);
  ds := OGROpen(PAnsiChar(utf8), 0, nil);
  if ds = nil then
    raise EVectorLayerError.Create('No se pudo abrir el archivo: ' + FileName);

  owner := TDataSourceOwner.Create(ds);
  owner.AddRef;   // ref del creador (protege el handle durante la extraccion)
  try
    if OGR_DS_GetLayerCount(ds) = 0 then
      raise EVectorLayerError.Create('El archivo no contiene capas: ' + FileName);

    layer := OGR_DS_GetLayer(ds, 0);
    if layer = nil then
      raise EVectorLayerError.Create('No se pudo obtener la capa 0.');

    ExtractLayer(layer);

    FLayer := layer;
    FOwner := owner;
    owner.AddRef;   // ref de esta capa
  finally
    owner.Release;  // libera la ref del creador
  end;
end;

class function TVectorLayer.LoadLayers(const FileName: string;
  Progress: TLoadProgressEvent): TArray<TVectorLayer>;
var
  utf8: UTF8String;
  ds: OGRDataSourceH;
  layer: OGRLayerH;
  owner: TDataSourceOwner;
  count, i: Integer;
begin
  OGRRegisterAll;
  utf8 := UTF8String(FileName);
  ds := OGROpen(PAnsiChar(utf8), 0, nil);
  if ds = nil then
    raise EVectorLayerError.Create('No se pudo abrir el archivo: ' + FileName);

  owner := TDataSourceOwner.Create(ds);
  owner.AddRef;   // ref del creador
  try
    try
      count := OGR_DS_GetLayerCount(ds);
      if count = 0 then
        raise EVectorLayerError.Create('El archivo no contiene capas: ' + FileName);

      SetLength(Result, count);
      for i := 0 to count - 1 do begin
        layer := OGR_DS_GetLayer(ds, i);
        if layer = nil then
          raise EVectorLayerError.Create(Format('No se pudo obtener la capa %d.', [i]));

        Result[i] := TVectorLayer.Create;
        Result[i].FFileName := FileName;
        Result[i].FLayerIndex := i;
        Result[i].FProgress := Progress;
        Result[i].FOwner := owner;
        owner.AddRef;   // ref de esta capa
        Result[i].FLayer := layer;
        Result[i].ExtractLayer(layer);
      end;
    except
      for i := 0 to High(Result) do
        if Result[i] <> nil then
          Result[i].Free;
      Result := nil;
      raise;
    end;
  finally
    owner.Release;  // libera la ref del creador
  end;
end;

function TVectorLayer.GetFeatureAttributes(FeatureIndex: Integer;
  out Names, Values: TStringArray): Boolean;
var
  feat: OGRFeatureH;
  featDefn: OGRFeatureDefnH;
  fieldCount, i: Integer;
begin
  Result := False;
  Names := nil;
  Values := nil;

  if (FeatureIndex < 0) or (FeatureIndex >= Length(FFeatures)) then
    Exit;
  if FLayer = nil then
    Exit;

  feat := OGR_L_GetFeature(FLayer, LongInt(FFeatures[FeatureIndex].FID));
  if feat = nil then
    Exit;

  try
    featDefn := OGR_L_GetLayerDefn(FLayer);
    fieldCount := OGR_FD_GetFieldCount(featDefn);
    SetLength(Names, fieldCount);
    SetLength(Values, fieldCount);
    for i := 0 to fieldCount - 1 do begin
      Names[i] := UTF8ToString(OGR_Fld_GetNameRef(OGR_FD_GetFieldDefn(featDefn, i)));
      Values[i] := UTF8ToString(OGR_F_GetFieldAsString(feat, i));
    end;
    Result := True;
  finally
    OGR_F_Destroy(feat);
  end;
end;

procedure TVectorLayer.ForEachAttributeRow(const Callback: TAttributeRowEvent);
var
  feat: OGRFeatureH;
  featDefn: OGRFeatureDefnH;
  fieldCount, i: Integer;
  Values: TStringArray;
begin
  if (FLayer = nil) or (not Assigned(Callback)) then
    Exit;

  featDefn := OGR_L_GetLayerDefn(FLayer);
  fieldCount := OGR_FD_GetFieldCount(featDefn);
  SetLength(Values, fieldCount);

  OGR_L_ResetReading(FLayer);
  feat := OGR_L_GetNextFeature(FLayer);
  while feat <> nil do begin
    for i := 0 to fieldCount - 1 do
      Values[i] := UTF8ToString(OGR_F_GetFieldAsString(feat, i));
    if not Callback(Values) then begin
      OGR_F_Destroy(feat);
      Break;
    end;
    OGR_F_Destroy(feat);
    feat := OGR_L_GetNextFeature(FLayer);
  end;
end;

function TVectorLayer.IdentifyAtWorld(const P: TPointD; Tolerance: Double): Integer;
var
  feat: OGRFeatureH;
  fid: Int64;
  idx: Integer;
  d, bestD: Double;
begin
  Result := -1;
  if (FLayer = nil) or (FFidToIndex = nil) then
    Exit;

  bestD := Tolerance;
  OGR_L_SetSpatialFilterRect(FLayer, P.X - Tolerance, P.Y - Tolerance,
                             P.X + Tolerance, P.Y + Tolerance);
  try
    OGR_L_ResetReading(FLayer);
    feat := OGR_L_GetNextFeature(FLayer);
    while feat <> nil do begin
      fid := OGR_F_GetFID(feat);
      if FFidToIndex.TryGetValue(fid, idx) then begin
        d := DistanceToGeometry(P, FFeatures[idx].Geometry);
        if d <= bestD then begin
          bestD := d;
          Result := idx;
        end;
      end;
      OGR_F_Destroy(feat);
      feat := OGR_L_GetNextFeature(FLayer);
    end;
  finally
    OGR_L_SetSpatialFilter(FLayer, nil);
  end;
end;

end.
