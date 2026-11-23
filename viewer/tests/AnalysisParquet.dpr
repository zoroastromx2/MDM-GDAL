program AnalysisParquet;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  VectorLayer,
  VectorAnalysis;

var
  Layers, Res: TArray<TVectorLayer>;
  outFile: string;
  i: Integer;
begin
  outFile := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) +
    'mdm_buffer_test.parquet';
  DeleteFile(outFile);

  Layers := TVectorLayer.LoadLayers(
    'D:\AAB\DELPHI_GDAL\MDM-GDAL\viewer\tests\data\analysis_sample.gpkg');
  if Length(Layers) <> 2 then begin
    WriteLn('FAIL: cargar analysis_sample.gpkg');
    Halt(1);
  end;

  if not TVectorAnalysis.Buffer(Layers[0], 2.0, outFile, 'buf') then begin
    WriteLn('FAIL: buffer a Parquet');
    Halt(1);
  end;

  Res := TVectorLayer.LoadLayers(outFile);
  if Length(Res) <> 1 then begin
    WriteLn('FAIL: reabrir Parquet');
    Halt(1);
  end;
  if Res[0].FeatureCount <> 1 then begin
    WriteLn('FAIL: entidades');
    Halt(1);
  end;
  WriteLn(Format('ANALYSIS-PARQUET OK: features=%d hasGeometry=%s',
    [Res[0].FeatureCount, BoolToStr(Res[0].HasGeometry, True)]));

  for i := 0 to High(Res) do
    Res[i].Free;
  for i := 0 to High(Layers) do
    Layers[i].Free;
end.
