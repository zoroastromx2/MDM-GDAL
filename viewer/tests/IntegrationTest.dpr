program IntegrationTest;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  gdalcore,
  ogr,
  GeometryModel,
  VectorLayer;

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
  i, j: Integer;
  f: TFeature;
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
      for j := 0 to High(f.Attributes) do
        WriteLn(Format('      %s = %s', [f.Attributes[j].Name, f.Attributes[j].Value]));
    end;

    if L.FeatureCount <> 3 then begin
      WriteLn('FAIL: se esperaban 3 entidades');
      Halt(1);
    end;

    { validación UTF-8 -> Unicode en memoria (sin depender de la consola) }
    if L.Features[0].Attributes[0].Value <> 'Polígono A' then begin
      WriteLn('FAIL: atributo UTF-8 no coincide (Polígono A)');
      Halt(1);
    end;
    if L.Features[1].Attributes[0].Value <> 'Línea B' then begin
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
    for k := 0 to Layers[i].FeatureCount - 1 do
      WriteLn(Format('        feat[%d] kind=%d', [k, Integer(Layers[i].Features[k].Geometry.Kind)]));
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
