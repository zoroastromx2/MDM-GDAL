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

var
  L: TVectorLayer;
  i, j: Integer;
  f: TFeature;
begin
  DumpEnumValues;

  L := TVectorLayer.Create;
  try
    L.Load('D:\AAB\DELPHI_GDAL\viewer\tests\data\sample.geojson');

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

    WriteLn('INTEGRATION OK');
  finally
    L.Free;
  end;
end.
