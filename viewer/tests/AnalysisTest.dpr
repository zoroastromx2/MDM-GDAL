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

var
  Layers, Res: TArray<TVectorLayer>;
  i: Integer;
  outBuf, outInter, outUnion: string;
begin
  OGRRegisterAll;
  outBuf := DataDir + 'tmp_buffer.gpkg';
  outInter := DataDir + 'tmp_inter.gpkg';
  outUnion := DataDir + 'tmp_union.gpkg';
  DeleteFile(outBuf);
  DeleteFile(outInter);
  DeleteFile(outUnion);

  Layers := TVectorLayer.LoadLayers(DataDir + 'analysis_sample.gpkg');
  if Length(Layers) <> 2 then begin
    WriteLn('FAIL: se esperaban 2 capas, hay ', Length(Layers));
    Halt(1);
  end;

  { buffer: capa_a (0,0)-(10,10) con distancia 2 -> aprox (-2,-2)-(12,12) }
  if not TVectorAnalysis.Buffer(Layers[0], 2.0, outBuf, 'buf') then begin
    WriteLn('FAIL: buffer'); Halt(1);
  end;
  Res := TVectorLayer.LoadLayers(outBuf);
  if Length(Res) <> 1 then begin WriteLn('FAIL: buffer no produjo 1 capa'); Halt(1); end;
  if Res[0].FeatureCount <> 1 then begin WriteLn('FAIL: buffer no produjo 1 entidad'); Halt(1); end;
  WriteLn(Format('Buffer OK: extent=(%.2f,%.2f)-(%.2f,%.2f)',
    [Res[0].Extent.MinX, Res[0].Extent.MinY, Res[0].Extent.MaxX, Res[0].Extent.MaxY]));
  for i := 0 to High(Res) do Res[i].Free;

  { interseccion: capa_a ∩ capa_b -> (5,5)-(10,10) }
  if not TVectorAnalysis.Intersection(Layers[0], Layers[1], outInter, 'inter') then begin
    WriteLn('FAIL: interseccion'); Halt(1);
  end;
  Res := TVectorLayer.LoadLayers(outInter);
  if Length(Res) <> 1 then begin WriteLn('FAIL: interseccion no produjo 1 capa'); Halt(1); end;
  if Res[0].FeatureCount <> 1 then begin WriteLn('FAIL: interseccion no produjo 1 entidad'); Halt(1); end;
  WriteLn(Format('Interseccion OK: extent=(%.2f,%.2f)-(%.2f,%.2f)',
    [Res[0].Extent.MinX, Res[0].Extent.MinY, Res[0].Extent.MaxX, Res[0].Extent.MaxY]));
  for i := 0 to High(Res) do Res[i].Free;

  { union: capa_a + capa_b -> 2 entidades }
  if not TVectorAnalysis.Union(Layers[0], Layers[1], outUnion, 'union') then begin
    WriteLn('FAIL: union'); Halt(1);
  end;
  Res := TVectorLayer.LoadLayers(outUnion);
  if Length(Res) <> 1 then begin WriteLn('FAIL: union no produjo 1 capa'); Halt(1); end;
  if Res[0].FeatureCount <> 2 then begin WriteLn('FAIL: union no produjo 2 entidades, hay ', Res[0].FeatureCount); Halt(1); end;
  WriteLn('Union OK: 2 entidades');
  for i := 0 to High(Res) do Res[i].Free;

  for i := 0 to High(Layers) do Layers[i].Free;

  DeleteFile(outBuf);
  DeleteFile(outInter);
  DeleteFile(outUnion);

  WriteLn('ANALYSIS OK');
end.
