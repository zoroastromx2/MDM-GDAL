program ExportTest;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  GeometryModel,
  VectorLayer,
  VectorAnalysis;

var
  Failed, Checks: Integer;

procedure Check(Cond: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not Cond then begin
    Inc(Failed);
    WriteLn('FAIL: ', Msg);
  end;
end;

var
  src, dst: TArray<TVectorLayer>;
  outFile: string;
  i: Integer;
  names1, names2, vals1, vals2: TStringArray;
begin
  Failed := 0;
  Checks := 0;

  outFile := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) +
    'mdm_export_test.parquet';
  if FileExists(outFile) then
    DeleteFile(outFile);

  src := TVectorLayer.LoadLayers(
    'D:\AAB\DELPHI_GDAL\MDM-GDAL\viewer\tests\data\sample.parquet');
  Check(Length(src) = 1, 'source: 1 capa');
  if Length(src) = 1 then begin
    Check(TVectorAnalysis.ExportToParquet(src[0], outFile), 'exportar a Parquet');

    dst := TVectorLayer.LoadLayers(outFile);
    Check(Length(dst) = 1, 'reabrir: 1 capa');
    if Length(dst) = 1 then begin
      Check(dst[0].FeatureCount = src[0].FeatureCount, 'mismo nº de entidades');
      Check(Abs(dst[0].Extent.MinX - src[0].Extent.MinX) < 1e-6, 'misma MinX');
      Check(Abs(dst[0].Extent.MaxX - src[0].Extent.MaxX) < 1e-6, 'misma MaxX');
      Check(Abs(dst[0].Extent.MinY - src[0].Extent.MinY) < 1e-6, 'misma MinY');
      Check(Abs(dst[0].Extent.MaxY - src[0].Extent.MaxY) < 1e-6, 'misma MaxY');
      Check(dst[0].HasGeometry, 'reabierto: tiene geometría');

      if src[0].GetFeatureAttributes(0, names1, vals1) and
         dst[0].GetFeatureAttributes(0, names2, vals2) then begin
        Check((Length(vals1) > 0) and (Length(vals2) > 0) and
          (vals1[0] = vals2[0]), 'mismo valor de atributo');
      end
      else
        Check(False, 'atributos legibles');
    end;
    for i := 0 to High(dst) do
      dst[i].Free;
  end;
  for i := 0 to High(src) do
    src[i].Free;

  if Failed = 0 then
    WriteLn(Format('EXPORT OK: %d checks', [Checks]))
  else
    WriteLn(Format('%d of %d checks FAILED', [Failed, Checks]));

  if Failed > 0 then
    Halt(1);
end.
