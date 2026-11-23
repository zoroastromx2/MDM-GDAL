program PerfProbe;

{$APPTYPE CONSOLE}

{ Rendimiento: carga un archivo y reporta conteos, tiempo, memoria, y un
  benchmark de identificar (índice espacial OGR vs barrido en memoria).
  Uso: PerfProbe.exe <archivo> }

uses
  System.SysUtils,
  System.Diagnostics,
  gdalcore,
  ogr,
  GeometryModel,
  VectorLayer;

function HeapBytes: Int64;
begin
  Result := Int64(GetHeapStatus.TotalAllocated);
end;

var
  Layers: TArray<TVectorLayer>;
  sw: TStopwatch;
  i: Integer;
  memBefore, memAfter: Int64;
  totalFeat: Int64;
  big: TVectorLayer;
  bigIdx: Integer;
  c: TPointD;
  tol: Double;
  iters, k, fi: Integer;
  tNew, tOld: Int64;
begin
  if ParamCount < 1 then begin
    WriteLn('uso: PerfProbe <archivo>');
    Halt(2);
  end;

  WriteLn('Archivo: ', ParamStr(1));

  memBefore := HeapBytes;
  sw := TStopwatch.StartNew;
  Layers := TVectorLayer.LoadLayers(ParamStr(1));
  sw.Stop;
  memAfter := HeapBytes;

  totalFeat := 0;
  big := nil;
  bigIdx := -1;
  WriteLn(Format('%-18s %10s', ['Capa', 'Features']));
  WriteLn(StringOfChar('-', 30));
  for i := 0 to High(Layers) do begin
    WriteLn(Format('%-18s %10d', [Layers[i].LayerName, Layers[i].FeatureCount]));
    Inc(totalFeat, Layers[i].FeatureCount);
    if Layers[i].FeatureCount > bigIdx then begin
      bigIdx := Layers[i].FeatureCount;
      big := Layers[i];
    end;
  end;
  WriteLn(StringOfChar('-', 30));
  WriteLn(Format('Total: %d capas, %d entidades', [Length(Layers), totalFeat]));
  WriteLn(Format('Tiempo de carga: %d ms', [sw.ElapsedMilliseconds]));
  WriteLn(Format('Memoria del modelo (heap Delphi): %.1f MB',
    [(memAfter - memBefore) / (1024 * 1024)]));

  { benchmark de identificar en la capa más grande }
  if big <> nil then begin
    c := ExtentCenter(big.Extent);
    tol := (ExtentWidth(big.Extent) + ExtentHeight(big.Extent)) * 0.001;
    iters := 200;

    sw := TStopwatch.StartNew;
    for k := 1 to iters do
      big.IdentifyAtWorld(c, tol);
    sw.Stop;
    tNew := sw.ElapsedMilliseconds;

    sw := TStopwatch.StartNew;
    for k := 1 to iters do
      FindNearestFeature(big.Features, c, fi);
    sw.Stop;
    tOld := sw.ElapsedMilliseconds;

    WriteLn(Format('Identificar (capa %s, %d entidades):',
      [big.LayerName, big.FeatureCount]));
    WriteLn(Format('  Indice espacial OGR: %d ms / %d iter = %.3f ms por clic',
      [tNew, iters, tNew / iters]));
    WriteLn(Format('  Barrido en memoria : %d ms / %d iter = %.3f ms por clic',
      [tOld, iters, tOld / iters]));
  end;

  for i := 0 to High(Layers) do
    Layers[i].Free;
end.
