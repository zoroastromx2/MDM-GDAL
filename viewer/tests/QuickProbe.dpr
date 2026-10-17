program QuickProbe;

{$APPTYPE CONSOLE}

{ Diagnostico rapido: carga todas las capas de un archivo y muestra su
  nombre, conteo, extension y tipo de geometria. Uso:
    QuickProbe.exe <archivo> }

uses
  SysUtils,
  gdalcore,
  ogr,
  GeometryModel,
  VectorLayer;

var
  Layers: TArray<TVectorLayer>;
  i, j: Integer;
begin
  if ParamCount < 1 then begin
    WriteLn('uso: QuickProbe <archivo>');
    Halt(2);
  end;

  Layers := TVectorLayer.LoadLayers(ParamStr(1));
  WriteLn('Capas: ', Length(Layers));

  for i := 0 to High(Layers) do begin
    WriteLn(Format('[%d] %s  features=%d  extent=(%.4f,%.4f)-(%.4f,%.4f)',
      [i, Layers[i].LayerName, Layers[i].FeatureCount,
       Layers[i].Extent.MinX, Layers[i].Extent.MinY,
       Layers[i].Extent.MaxX, Layers[i].Extent.MaxY]));
    for j := 0 to Layers[i].FeatureCount - 1 do
      WriteLn(Format('    feat[%d] kind=%d',
        [j, Integer(Layers[i].Features[j].Geometry.Kind)]));
  end;

  for i := 0 to High(Layers) do
    Layers[i].Free;
end.
