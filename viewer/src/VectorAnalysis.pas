unit VectorAnalysis;

interface

uses
  SysUtils,
  gdalcore,
  ogr,
  VectorLayer;

type
  EAnalysisError = class(Exception);

  {
    Ejecuta análisis vectoriales en proceso (el motor SQL que usa ogr2ogr
    -dialect SQLITE) y escribe el resultado en un GeoPackage nuevo.
    Primera iteración: Buffer (1 capa), Intersección (2 capas) y Unión (2 capas,
    combinando entidades). Las operaciones de 2 capas requieren que ambas estén
    en el mismo datasource.
  }
  TVectorAnalysis = class
  private
    class function GeomColumn(const Layer: OGRLayerH): string;
    class function CreateResultDataSource(const OutFile: string): OGRDataSourceH;
    class function RunSql(const Ds: OGRDataSourceH; const Sql: string;
      const OutFile, OutLayerName: string): Boolean;
  public
    class function Buffer(const Layer: TVectorLayer; Distance: Double;
      const OutFile, OutLayerName: string): Boolean;
    class function Intersection(const LayerA, LayerB: TVectorLayer;
      const OutFile, OutLayerName: string): Boolean;
    class function Union(const LayerA, LayerB: TVectorLayer;
      const OutFile, OutLayerName: string): Boolean;
  end;

implementation

class function TVectorAnalysis.GeomColumn(const Layer: OGRLayerH): string;
var
  p: CPChar;
begin
  p := OGR_L_GetGeometryColumn(Layer);
  if (p = nil) or (p^ = #0) then
    Result := 'geom'
  else
    Result := UTF8ToString(p);
end;

class function TVectorAnalysis.CreateResultDataSource(const OutFile: string): OGRDataSourceH;
var
  drv: OGRSFDriverH;
  utf8: UTF8String;
begin
  drv := OGRGetDriverByName(PAnsiChar(AnsiString('GPKG')));
  if drv = nil then
    raise EAnalysisError.Create('No se encontró el driver GPKG.');
  utf8 := UTF8String(OutFile);
  Result := OGR_Dr_CreateDataSource(drv, PAnsiChar(utf8), nil);
  if Result = nil then
    raise EAnalysisError.Create('No se pudo crear el archivo de salida: ' + OutFile);
end;

class function TVectorAnalysis.RunSql(const Ds: OGRDataSourceH; const Sql: string;
  const OutFile, OutLayerName: string): Boolean;
var
  res, dst, copied: OGRLayerH;
  sqlUtf8, nameUtf8: UTF8String;
begin
  Result := False;
  sqlUtf8 := UTF8String(Sql);
  res := OGR_DS_ExecuteSQL(Ds, PAnsiChar(sqlUtf8), nil, PAnsiChar(AnsiString('SQLITE')));
  if res = nil then
    raise EAnalysisError.Create('La consulta no produjo resultado.');

  try
    dst := CreateResultDataSource(OutFile);
    try
      nameUtf8 := UTF8String(OutLayerName);
      copied := OGR_DS_CopyLayer(dst, res, PAnsiChar(nameUtf8), nil);
      if copied = nil then
        raise EAnalysisError.Create('No se pudo copiar el resultado.');
      Result := True;
    finally
      OGRReleaseDataSource(dst);
    end;
  finally
    OGR_DS_ReleaseResultSet(Ds, res);
  end;
end;

class function TVectorAnalysis.Buffer(const Layer: TVectorLayer; Distance: Double;
  const OutFile, OutLayerName: string): Boolean;
var
  gc, sql: string;
begin
  if Layer = nil then
    raise EAnalysisError.Create('Capa de origen no válida.');
  if Distance <= 0 then
    raise EAnalysisError.Create('La distancia del buffer debe ser mayor que 0.');

  gc := GeomColumn(Layer.OgrLayer);
  sql := Format('SELECT ST_Buffer(%s, %.8f) AS %s, * FROM "%s"',
    [gc, Distance, gc, Layer.LayerName]);
  Result := RunSql(Layer.DataSource, sql, OutFile, OutLayerName);
end;

class function TVectorAnalysis.Intersection(const LayerA, LayerB: TVectorLayer;
  const OutFile, OutLayerName: string): Boolean;
var
  ga, gb, sql: string;
begin
  if (LayerA = nil) or (LayerB = nil) then
    raise EAnalysisError.Create('Se requieren dos capas para la intersección.');
  if LayerA.DataSource <> LayerB.DataSource then
    raise EAnalysisError.Create('La intersección requiere capas del mismo archivo.');

  ga := GeomColumn(LayerA.OgrLayer);
  gb := GeomColumn(LayerB.OgrLayer);
  sql := Format('SELECT ST_Intersection(a.%s, b.%s) AS %s, a.* FROM "%s" a, "%s" b WHERE ST_Intersects(a.%s, b.%s)',
    [ga, gb, ga, LayerA.LayerName, LayerB.LayerName, ga, gb]);
  Result := RunSql(LayerA.DataSource, sql, OutFile, OutLayerName);
end;

class function TVectorAnalysis.Union(const LayerA, LayerB: TVectorLayer;
  const OutFile, OutLayerName: string): Boolean;
var
  dst, copied: OGRDataSourceH;
  dstLayer: OGRLayerH;
  nameUtf8: UTF8String;
  feat, clone: OGRFeatureH;
begin
  if (LayerA = nil) or (LayerB = nil) then
    raise EAnalysisError.Create('Se requieren dos capas para la unión.');
  if LayerA.DataSource <> LayerB.DataSource then
    raise EAnalysisError.Create('La unión requiere capas del mismo archivo.');

  dst := CreateResultDataSource(OutFile);
  try
    nameUtf8 := UTF8String(OutLayerName);
    copied := OGR_DS_CopyLayer(dst, LayerA.OgrLayer, PAnsiChar(nameUtf8), nil);
    if copied = nil then
      raise EAnalysisError.Create('No se pudo copiar la capa A.');

    { Agregar las entidades de B al resultado (misma capa). }
    dstLayer := copied;
    OGR_L_ResetReading(LayerB.OgrLayer);
    feat := OGR_L_GetNextFeature(LayerB.OgrLayer);
    while feat <> nil do begin
      clone := OGR_F_Clone(feat);
      try
        OGR_F_SetFID(clone, OGRNullFID);   // que OGR asigne un FID nuevo (evita duplicados)
        OGR_L_CreateFeature(dstLayer, clone);
      finally
        OGR_F_Destroy(clone);
      end;
      OGR_F_Destroy(feat);
      feat := OGR_L_GetNextFeature(LayerB.OgrLayer);
    end;
    Result := True;
  finally
    OGRReleaseDataSource(dst);
  end;
end;

end.
