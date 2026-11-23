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
    combinando entidades). Funciona aunque las capas vengan de archivos
    (datasources) distintos: la intersección copia ambas a un GPKG temporal.
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
    class function ExportToParquet(const Layer: TVectorLayer;
      const OutFile: string): Boolean;
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
  utf8, drvUtf8: UTF8String;
  driverName: string;
begin
  if SameText(ExtractFileExt(OutFile), '.parquet') then
    driverName := 'Parquet'
  else
    driverName := 'GPKG';
  drvUtf8 := UTF8String(driverName);
  drv := OGRGetDriverByName(PAnsiChar(drvUtf8));
  if drv = nil then
    raise EAnalysisError.Create('No se encontró el driver ' + driverName + '.');
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
  tempPath: string;
  tempUtf8, nameUtf8, sqlUtf8: UTF8String;
  drv: OGRSFDriverH;
  tempDs, dst: OGRDataSourceH;
  la, lb, res, copied: OGRLayerH;
  ga, gb, sql: string;
begin
  if (LayerA = nil) or (LayerB = nil) then
    raise EAnalysisError.Create('Se requieren dos capas para la intersección.');

  { Copiar ambas capas a un GeoPackage temporal para poder hacer el join SQL
    aunque provengan de archivos (datasources) distintos. }
  tempPath := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) +
    'mdm_overlay_' + FormatDateTime('yyyymmddhhnnsszzz', Now) + '.gpkg';
  if FileExists(tempPath) then
    DeleteFile(tempPath);

  drv := OGRGetDriverByName(PAnsiChar(AnsiString('GPKG')));
  if drv = nil then
    raise EAnalysisError.Create('No se encontró el driver GPKG.');
  tempUtf8 := UTF8String(tempPath);
  tempDs := OGR_Dr_CreateDataSource(drv, PAnsiChar(tempUtf8), nil);
  if tempDs = nil then
    raise EAnalysisError.Create('No se pudo crear el archivo temporal.');

  try
    la := OGR_DS_CopyLayer(tempDs, LayerA.OgrLayer, PAnsiChar(AnsiString('a')), nil);
    lb := OGR_DS_CopyLayer(tempDs, LayerB.OgrLayer, PAnsiChar(AnsiString('b')), nil);
    if (la = nil) or (lb = nil) then
      raise EAnalysisError.Create('No se pudieron copiar las capas al temporal.');

    ga := GeomColumn(la);
    gb := GeomColumn(lb);
    sql := Format('SELECT ST_Intersection(a.%s, b.%s) AS %s, a.* FROM "a" a, "b" b WHERE ST_Intersects(a.%s, b.%s)',
      [ga, gb, ga, ga, gb]);

    sqlUtf8 := UTF8String(sql);
    res := OGR_DS_ExecuteSQL(tempDs, PAnsiChar(sqlUtf8), nil, PAnsiChar(AnsiString('SQLITE')));
    if res = nil then
      raise EAnalysisError.Create('La intersección no produjo resultado.');

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
      OGR_DS_ReleaseResultSet(tempDs, res);
    end;
  finally
    OGRReleaseDataSource(tempDs);
    DeleteFile(tempPath);
  end;
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

class function TVectorAnalysis.ExportToParquet(const Layer: TVectorLayer;
  const OutFile: string): Boolean;
var
  drv: OGRSFDriverH;
  dst: OGRDataSourceH;
  copied: OGRLayerH;
  utf8, nameUtf8: UTF8String;
begin
  Result := False;
  if (Layer = nil) or (Layer.OgrLayer = nil) then
    raise EAnalysisError.Create('Capa de origen no válida.');

  drv := OGRGetDriverByName(PAnsiChar(AnsiString('Parquet')));
  if drv = nil then
    raise EAnalysisError.Create('No se encontró el driver Parquet.');

  utf8 := UTF8String(OutFile);
  dst := OGR_Dr_CreateDataSource(drv, PAnsiChar(utf8), nil);
  if dst = nil then
    raise EAnalysisError.Create('No se pudo crear el archivo de salida: ' + OutFile);

  try
    nameUtf8 := UTF8String(Layer.LayerName);
    copied := OGR_DS_CopyLayer(dst, Layer.OgrLayer, PAnsiChar(nameUtf8), nil);
    if copied = nil then
      raise EAnalysisError.Create('No se pudo copiar la capa a Parquet.');
    Result := True;
  finally
    OGRReleaseDataSource(dst);
  end;
end;

end.
