unit VectorLayer;

interface

uses
  SysUtils,
  System.UITypes,
  gdalcore,
  ogr,
  GeometryModel;

type
  EVectorLayerError = class(Exception);

  TStringArray = array of string;

  {
    Abre un archivo vectorial con OGR, extrae todas las entidades a un modelo
    en memoria (GeometryModel) y cierra el datasource. El resto de la app no
    depende de handles OGR.
  }
  TVectorLayer = class
  private
    FFileName: string;
    FLayerName: string;
    FFeatures: TFeatureArray;
    FExtent: TExtent;
    FFieldCount: Integer;
    FFieldNames: TStringArray;
    FVisible: Boolean;
    FFillEnabled: Boolean;
    FFillColor: TColor;
    FLineColor: TColor;
    FLineWidth: Integer;
    procedure ExtractRing(geom: OGRGeometryH; var Ring: TPointArray);
    function GeometryToModel(geom: OGRGeometryH): TFeatureGeometry;
    procedure ExtractLayer(layer: OGRLayerH);
  public
    constructor Create;
    procedure Load(const FileName: string);
    procedure Clear;
    class function LoadLayers(const FileName: string): TArray<TVectorLayer>;

    property FileName: string read FFileName;
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

constructor TVectorLayer.Create;
begin
  inherited Create;
  FVisible := True;
  FFillEnabled := True;
  FFillColor := $00FF0000;   // azul (BGR)
  FLineColor := $00FF0000;   // azul
  FLineWidth := 1;
  ExtentReset(FExtent);
end;

procedure TVectorLayer.Clear;
begin
  FFeatures := nil;
  FLayerName := '';
  FFileName := '';
  FFieldCount := 0;
  FFieldNames := nil;
  ExtentReset(FExtent);
end;

function TVectorLayer.FeatureCount: Integer;
begin
  Result := Length(FFeatures);
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

  OGR_L_ResetReading(layer);
  feat := OGR_L_GetNextFeature(layer);
  while feat <> nil do begin
    if n >= Length(FFeatures) then
      SetLength(FFeatures, n + 1024);

    featRec.FID := OGR_F_GetFID(feat);
    featRec.Geometry := GeometryToModel(OGR_F_GetGeometryRef(feat));

    SetLength(featRec.Attributes, fieldCount);
    for i := 0 to fieldCount - 1 do begin
      featRec.Attributes[i].Name := FFieldNames[i];
      featRec.Attributes[i].Value := UTF8ToString(OGR_F_GetFieldAsString(feat, i));
    end;

    FFeatures[n] := featRec;
    Inc(n);

    OGR_F_Destroy(feat);
    feat := OGR_L_GetNextFeature(layer);
  end;
  SetLength(FFeatures, n);

  FExtent := FeaturesExtent(FFeatures);
end;

procedure TVectorLayer.Load(const FileName: string);
var
  utf8: UTF8String;
  ds: OGRDataSourceH;
  layer: OGRLayerH;
begin
  Clear;
  FFileName := FileName;

  OGRRegisterAll;
  utf8 := UTF8String(FileName);
  ds := OGROpen(PAnsiChar(utf8), 0, nil);
  if ds = nil then
    raise EVectorLayerError.Create('No se pudo abrir el archivo: ' + FileName);

  try
    if OGR_DS_GetLayerCount(ds) = 0 then
      raise EVectorLayerError.Create('El archivo no contiene capas: ' + FileName);

    layer := OGR_DS_GetLayer(ds, 0);
    if layer = nil then
      raise EVectorLayerError.Create('No se pudo obtener la capa 0.');

    ExtractLayer(layer);
  finally
    OGRReleaseDataSource(ds);
  end;
end;

class function TVectorLayer.LoadLayers(const FileName: string): TArray<TVectorLayer>;
var
  utf8: UTF8String;
  ds: OGRDataSourceH;
  layer: OGRLayerH;
  count, i: Integer;
begin
  OGRRegisterAll;
  utf8 := UTF8String(FileName);
  ds := OGROpen(PAnsiChar(utf8), 0, nil);
  if ds = nil then
    raise EVectorLayerError.Create('No se pudo abrir el archivo: ' + FileName);

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
      Result[i].ExtractLayer(layer);
    end;
  finally
    OGRReleaseDataSource(ds);
  end;
end;

end.
