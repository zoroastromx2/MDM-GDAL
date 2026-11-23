program GeoParquetBench;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  System.Diagnostics,
  GeometryModel,
  VectorLayer;

var
  Layers: TArray<TVectorLayer>;
  fileName: string;
  sw: TStopwatch;
  i: Integer;
  idx: Integer;
  c: TPointD;
  loadMs, identifyMs: Int64;
  ext: TExtent;
begin
  fileName := ParamStr(1);
  if fileName = '' then
    fileName := 'D:\F\IRIS 4.0\2026\GeoParquet\09Man.parquet';

  sw := TStopwatch.StartNew;
  Layers := TVectorLayer.LoadLayers(fileName);
  sw.Stop;
  loadMs := sw.ElapsedMilliseconds;

  if Length(Layers) = 0 then begin
    WriteLn('No layers');
    Halt(1);
  end;

  ext := Layers[0].Extent;
  WriteLn(Format('LOAD: layer=%s features=%d ms=%d', [Layers[0].LayerName,
    Layers[0].FeatureCount, loadMs]));
  WriteLn(Format('EXTENT: (%f,%f)-(%f,%f)', [ext.MinX, ext.MinY, ext.MaxX, ext.MaxY]));

  // 20 identificaciones en puntos del centro/extent
  sw := TStopwatch.StartNew;
  for i := 0 to 19 do begin
    c.X := ext.MinX + (ext.MaxX - ext.MinX) * (0.25 + 0.5 * (i mod 4) / 3);
    c.Y := ext.MinY + (ext.MaxY - ext.MinY) * (0.25 + 0.5 * ((i div 4) mod 4) / 3);
    idx := Layers[0].IdentifyAtWorld(c, 100.0);
  end;
  sw.Stop;
  identifyMs := sw.ElapsedMilliseconds;
  WriteLn(Format('IDENTIFY: 20 clicks -> total=%dms avg=%.1fms (last idx=%d)',
    [identifyMs, identifyMs / 20.0, idx]));

  for i := 0 to High(Layers) do
    Layers[i].Free;
end.
