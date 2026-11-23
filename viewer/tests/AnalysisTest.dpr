program AnalysisTest;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  gdalcore,
  ogr,
  GeometryModel,
  VectorLayer,
  VectorAnalysis;

function DataDir: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + '..\data\';
end;

procedure CheckLayers(const Layers: TArray<TVectorLayer>; ExpectedCount: Integer;
  const Msg: string);
begin
  if Length(Layers) <> ExpectedCount then begin
    WriteLn('FAIL: ', Msg, ' (capas=', Length(Layers), ', esperadas=', ExpectedCount, ')');
    Halt(1);
  end;
end;

procedure FreeLayers(const Layers: TArray<TVectorLayer>);
var
  i: Integer;
begin
  for i := 0 to High(Layers) do
    Layers[i].Free;
end;

var
  Layers, Res, LA, LB: TArray<TVectorLayer>;
  outBuf, outInter, outUnion, outXInter, outXUnion: string;
begin
  OGRRegisterAll;
  outBuf := DataDir + 'tmp_buffer.gpkg';
  outInter := DataDir + 'tmp_inter.gpkg';
  outUnion := DataDir + 'tmp_union.gpkg';
  outXInter := DataDir + 'tmp_xinter.gpkg';
  outXUnion := DataDir + 'tmp_xunion.gpkg';
  DeleteFile(outBuf);
  DeleteFile(outInter);
  DeleteFile(outUnion);
  DeleteFile(outXInter);
  DeleteFile(outXUnion);

  { --- mismo archivo: analysis_sample.gpkg (capa_a y capa_b) --- }
  Layers := TVectorLayer.LoadLayers(DataDir + 'analysis_sample.gpkg');
  CheckLayers(Layers, 2, 'analysis_sample.gpkg');

  if not TVectorAnalysis.Buffer(Layers[0], 2.0, outBuf, 'buf') then begin
    WriteLn('FAIL: buffer'); Halt(1);
  end;
  Res := TVectorLayer.LoadLayers(outBuf);
  CheckLayers(Res, 1, 'buffer');
  if Res[0].FeatureCount <> 1 then begin WriteLn('FAIL: buffer entidades'); Halt(1); end;
  WriteLn(Format('Buffer OK: extent=(%.2f,%.2f)-(%.2f,%.2f)',
    [Res[0].Extent.MinX, Res[0].Extent.MinY, Res[0].Extent.MaxX, Res[0].Extent.MaxY]));
  FreeLayers(Res);

  if not TVectorAnalysis.Intersection(Layers[0], Layers[1], outInter, 'inter') then begin
    WriteLn('FAIL: interseccion mismo archivo'); Halt(1);
  end;
  Res := TVectorLayer.LoadLayers(outInter);
  CheckLayers(Res, 1, 'interseccion mismo archivo');
  if Res[0].FeatureCount <> 1 then begin WriteLn('FAIL: interseccion entidades'); Halt(1); end;
  WriteLn(Format('Interseccion (mismo archivo) OK: extent=(%.2f,%.2f)-(%.2f,%.2f)',
    [Res[0].Extent.MinX, Res[0].Extent.MinY, Res[0].Extent.MaxX, Res[0].Extent.MaxY]));
  FreeLayers(Res);

  if not TVectorAnalysis.Union(Layers[0], Layers[1], outUnion, 'union') then begin
    WriteLn('FAIL: union mismo archivo'); Halt(1);
  end;
  Res := TVectorLayer.LoadLayers(outUnion);
  CheckLayers(Res, 1, 'union mismo archivo');
  if Res[0].FeatureCount <> 2 then begin WriteLn('FAIL: union entidades'); Halt(1); end;
  WriteLn('Union (mismo archivo) OK: 2 entidades');
  FreeLayers(Res);

  FreeLayers(Layers);

  { --- archivos distintos: analysis_a.geojson y analysis_b.geojson --- }
  LA := TVectorLayer.LoadLayers(DataDir + 'analysis_a.geojson');
  LB := TVectorLayer.LoadLayers(DataDir + 'analysis_b.geojson');
  CheckLayers(LA, 1, 'analysis_a.geojson');
  CheckLayers(LB, 1, 'analysis_b.geojson');

  if not TVectorAnalysis.Union(LA[0], LB[0], outXUnion, 'ux') then begin
    WriteLn('FAIL: union entre archivos'); Halt(1);
  end;
  Res := TVectorLayer.LoadLayers(outXUnion);
  CheckLayers(Res, 1, 'union entre archivos');
  if Res[0].FeatureCount <> 2 then begin WriteLn('FAIL: union entre archivos entidades'); Halt(1); end;
  WriteLn('Union (archivos distintos) OK: 2 entidades');
  FreeLayers(Res);

  if not TVectorAnalysis.Intersection(LA[0], LB[0], outXInter, 'ix') then begin
    WriteLn('FAIL: interseccion entre archivos'); Halt(1);
  end;
  Res := TVectorLayer.LoadLayers(outXInter);
  CheckLayers(Res, 1, 'interseccion entre archivos');
  if Res[0].FeatureCount <> 1 then begin WriteLn('FAIL: interseccion entre archivos entidades'); Halt(1); end;
  WriteLn(Format('Interseccion (archivos distintos) OK: extent=(%.2f,%.2f)-(%.2f,%.2f)',
    [Res[0].Extent.MinX, Res[0].Extent.MinY, Res[0].Extent.MaxX, Res[0].Extent.MaxY]));
  FreeLayers(Res);

  FreeLayers(LA);
  FreeLayers(LB);

  DeleteFile(outBuf);
  DeleteFile(outInter);
  DeleteFile(outUnion);
  DeleteFile(outXInter);
  DeleteFile(outXUnion);

  WriteLn('ANALYSIS OK');
end.
