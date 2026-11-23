program ParquetProbe;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  GeometryModel,
  VectorLayer;

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

procedure CheckClose(A, B, Eps: Double; const Msg: string);
begin
  Check(Abs(A - B) <= Eps, Format('%s (got %.9f, want %.9f)', [Msg, A, B]));
end;

var
  Layers: TArray<TVectorLayer>;
  Names, Values: TStringArray;
  idx, i: Integer;
begin
  Failed := 0;
  Checks := 0;

  { GeoParquet con geometría }
  Layers := TVectorLayer.LoadLayers(
    'D:\AAB\DELPHI_GDAL\MDM-GDAL\viewer\tests\data\sample.parquet');
  Check(Length(Layers) = 1, 'sample.parquet: 1 capa');
  if Length(Layers) = 1 then begin
    Check(Layers[0].HasGeometry, 'sample.parquet: tiene geometría');
    Check(Layers[0].FeatureCount = 3, 'sample.parquet: 3 entidades');
    CheckClose(Layers[0].Extent.MinX, -5, 1e-6, 'extent MinX');
    CheckClose(Layers[0].Extent.MinY, -5, 1e-6, 'extent MinY');
    CheckClose(Layers[0].Extent.MaxX, 20, 1e-6, 'extent MaxX');
    CheckClose(Layers[0].Extent.MaxY, 20, 1e-6, 'extent MaxY');

    if Layers[0].GetFeatureAttributes(0, Names, Values) then begin
      Check(Length(Names) = 2, 'atributos: 2 campos');
      Check((Length(Values) > 0) and (Values[0] = 'Polígono A'),
        'atributo name = Polígono A');
    end
    else
      Check(False, 'atributos: no se pudieron leer');

    idx := Layers[0].IdentifyAtWorld(MakePoint(8, 8), 0.5);
    Check(idx = 0, 'identificar en el polígono -> índice 0');
  end;
  for i := 0 to High(Layers) do
    Layers[i].Free;

  { Parquet plano, sin geometría }
  Layers := TVectorLayer.LoadLayers(
    'D:\AAB\DELPHI_GDAL\MDM-GDAL\viewer\tests\data\plain.parquet');
  Check(Length(Layers) = 1, 'plain.parquet: 1 capa');
  if Length(Layers) = 1 then begin
    Check(not Layers[0].HasGeometry, 'plain.parquet: sin geometría');
    Check(Layers[0].FeatureCount = 2, 'plain.parquet: 2 entidades');
  end;
  for i := 0 to High(Layers) do
    Layers[i].Free;

  if Failed = 0 then
    WriteLn(Format('PARQUET OK: %d checks', [Checks]))
  else
    WriteLn(Format('%d of %d checks FAILED', [Failed, Checks]));

  if Failed > 0 then
    Halt(1);
end.
