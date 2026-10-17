program PerfProbe;

{$APPTYPE CONSOLE}

{ Linea base de rendimiento: carga un archivo con LoadLayers y reporta
  conteos, tiempo de carga y memoria del heap Delphi usada por el modelo.
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
  WriteLn(Format('%-18s %10s', ['Capa', 'Features']));
  WriteLn(StringOfChar('-', 30));
  for i := 0 to High(Layers) do begin
    WriteLn(Format('%-18s %10d', [Layers[i].LayerName, Layers[i].FeatureCount]));
    Inc(totalFeat, Layers[i].FeatureCount);
  end;
  WriteLn(StringOfChar('-', 30));
  WriteLn(Format('Total: %d capas, %d entidades', [Length(Layers), totalFeat]));
  WriteLn(Format('Tiempo de carga: %d ms', [sw.ElapsedMilliseconds]));
  WriteLn(Format('Memoria del modelo (heap Delphi): %.1f MB',
    [(memAfter - memBefore) / (1024 * 1024)]));

  for i := 0 to High(Layers) do
    Layers[i].Free;
end.
