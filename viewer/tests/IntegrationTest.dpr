program IntegrationTest;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  gdalcore,
  ogr,
  GeometryModel,
  VectorLayer;

type
  TRowCounter = class
  public
    Count: Integer;
    function Row(const Values: TStringArray): Boolean;
  end;

function TRowCounter.Row(const Values: TStringArray): Boolean;
begin
  Inc(Count);
  Result := True;
end;

procedure DumpEnumValues;
begin
  WriteLn(Format('enum: wkbPoint=%d wkbLineString=%d wkbPolygon=%d wkbMultiPolygon=%d',
    [Ord(wkbPoint), Ord(wkbLineString), Ord(wkbPolygon), Ord(wkbMultiPolygon)]));
  WriteLn(Format('enum: wkbPoint25D=%d wkbPolygon25D=%d',
    [Ord(wkbPoint25D), Ord(wkbPolygon25D)]));
end;

function DataDir: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + '..\data\';
end;

procedure TestSingleLayer;
var
  L: TVectorLayer;
  i: Integer;
  f: TFeature;
  Names, Values: TStringArray;
begin
  L := TVectorLayer.Create;
  try
    L.Load(DataDir + 'sample.geojson');

    WriteLn('Layer    : ', L.LayerName);
    WriteLn('Fields   : ', L.FieldCount);
    WriteLn('Features : ', L.FeatureCount);
    WriteLn(Format('Extent   : (%f, %f) - (%f, %f)',
      [L.Extent.MinX, L.Extent.MinY, L.Extent.MaxX, L.Extent.MaxY]));

    for i := 0 to L.FeatureCount - 1 do begin
      f := L.Features[i];
      WriteLn(Format('  [%d] FID=%d kind=%d', [i, f.FID, Integer(f.Geometry.Kind)]));
    end;

    if L.FeatureCount <> 3 then begin
      WriteLn('FAIL: se esperaban 3 entidades');
      Halt(1);
    end;

    { atributos bajo demanda (v3): no se cargan con la geometria }
    if not L.GetFeatureAttributes(0, Names, Values) then begin
      WriteLn('FAIL: no se pudieron leer atributos de la entidad 0');
      Halt(1);
    end;
    Write('      attrs entidad 0: ');
    for i := 0 to High(Values) do begin
      if i > 0 then Write(', ');
      Write(Names[i], '=', Values[i]);
    end;
    WriteLn;
    if Values[0] <> 'Polígono A' then begin
      WriteLn('FAIL: atributo UTF-8 no coincide (Polígono A)');
      Halt(1);
    end;

    if not L.GetFeatureAttributes(1, Names, Values) then begin
      WriteLn('FAIL: no se pudieron leer atributos de la entidad 1');
      Halt(1);
    end;
    if Values[0] <> 'Línea B' then begin
      WriteLn('FAIL: atributo UTF-8 no coincide (Línea B)');
      Halt(1);
    end;

    if Abs(L.Extent.MinX - (-5)) > 1e-6 then begin WriteLn('FAIL: MinX'); Halt(1); end;
    if Abs(L.Extent.MinY - (-5)) > 1e-6 then begin WriteLn('FAIL: MinY'); Halt(1); end;
    if Abs(L.Extent.MaxX - 20) > 1e-6 then begin WriteLn('FAIL: MaxX'); Halt(1); end;
    if Abs(L.Extent.MaxY - 20) > 1e-6 then begin WriteLn('FAIL: MaxY'); Halt(1); end;

    { estilo por defecto (Task 10) }
    if not L.Visible then begin WriteLn('FAIL: Visible por defecto'); Halt(1); end;
    if not L.FillEnabled then begin WriteLn('FAIL: FillEnabled por defecto'); Halt(1); end;
    if L.FillColor <> $00FF0000 then begin WriteLn('FAIL: FillColor por defecto'); Halt(1); end;
    if L.LineColor <> $00FF0000 then begin WriteLn('FAIL: LineColor por defecto'); Halt(1); end;
  finally
    L.Free;
  end;
end;

procedure TestMultiLayer;
var
  Layers: TArray<TVectorLayer>;
  i, k: Integer;
  rc: TRowCounter;
begin
  Layers := TVectorLayer.LoadLayers(DataDir + 'multi.gpkg');

  if Length(Layers) <> 2 then begin
    WriteLn(Format('FAIL: se esperaban 2 capas, hay %d', [Length(Layers)]));
    Halt(1);
  end;

  for i := 0 to High(Layers) do begin
    WriteLn(Format('Layer[%d] name=%s fields=%d features=%d',
      [i, Layers[i].LayerName, Layers[i].FieldCount, Layers[i].FeatureCount]));
    WriteLn(Format('        Extent: (%f,%f)-(%f,%f)',
      [Layers[i].Extent.MinX, Layers[i].Extent.MinY,
       Layers[i].Extent.MaxX, Layers[i].Extent.MaxY]));
    Write('        FieldNames: ');
    for k := 0 to High(Layers[i].FieldNames) do begin
      if k > 0 then Write(', ');
      Write(Layers[i].FieldNames[k]);
    end;
    WriteLn;
  end;

  { recorrido de atributos bajo demanda: capa 0 debe entregar 3 filas }
  rc := TRowCounter.Create;
  try
    Layers[0].ForEachAttributeRow(rc.Row);
    WriteLn(Format('        Filas de atributos capa 0: %d', [rc.Count]));
    if rc.Count <> 3 then begin
      WriteLn('FAIL: filas de atributos capa 0');
      Halt(1);
    end;
  finally
    rc.Free;
  end;

  if Layers[0].LayerName <> 'capa_a' then begin WriteLn('FAIL: nombre capa 0'); Halt(1); end;
  if Layers[1].LayerName <> 'capa_b' then begin WriteLn('FAIL: nombre capa 1'); Halt(1); end;
  if Layers[0].FeatureCount <> 3 then begin WriteLn('FAIL: conteo capa 0'); Halt(1); end;
  if Layers[1].FeatureCount <> 2 then begin WriteLn('FAIL: conteo capa 1'); Halt(1); end;
  if Length(Layers[0].FieldNames) <> 2 then begin WriteLn('FAIL: campos capa 0'); Halt(1); end;

  for i := 0 to High(Layers) do
    Layers[i].Free;
end;

begin
  DumpEnumValues;
  TestSingleLayer;
  TestMultiLayer;
  WriteLn('INTEGRATION OK');
end.
