# Spec: analysis — Análisis vectorial en proceso (buffer, intersección, unión)

## Objective

Ejecutar análisis vectoriales sobre las capas cargadas usando SQL espacial en
proceso (el motor que usa `ogr2ogr -sql`, dialecto SQLite: `ST_Buffer`,
`ST_Intersection`, `ST_Union`) y escribir el resultado en un GeoPackage nuevo.
Primera iteración: **buffer** (1 capa + distancia), **intersección** (1 o 2
capas), **unión** (1 o 2 capas).

## Tech Stack

- Delphi + VCL + bindings OGR.
- APIs clave: `OGR_DS_ExecuteSQL` (dialecto `SQLITE`), `OGR_DS_CopyLayer`,
  `OGRGetDriverByName('GPKG')`, `OGR_Dr_CreateDataSource`,
  `OGR_DS_ReleaseResultSet`, `OGR_L_GetGeometryColumn`.

## Commands

```
powershell -File viewer\build.ps1 -Dpr viewer\GdalViewer.dpr
powershell -File viewer\build.ps1 -Dpr viewer\tests\AnalysisTest.dpr
```

## Project Structure

- `viewer/src/VectorAnalysis.pas` (nuevo) — ejecuta la operación y devuelve la
  ruta del GeoPackage generado.
- `viewer/src/AnalysisForm.pas` (nuevo) — diálogo: operación, capas, parámetros
  (distancia), nombre de salida.
- `viewer/src/Main.pas` — menú `Análisis` + llama al formulario.
- `viewer/tests/AnalysisTest.dpr` (nuevo) — test de consola sobre datos de muestra.

## Code Style

- Resultado vía `OGR_DS_ExecuteSQL` + `OGR_DS_CopyLayer` a un datasource GPKG;
  liberar el resultset con `OGR_DS_ReleaseResultSet` en `try..finally`.

```pascal
// esqueleto (buffer)
sql := Format('SELECT ST_Buffer(%s, %.6f) AS geometry, * FROM %s',
  [geomCol, Dist, LayerName]);
res := OGR_DS_ExecuteSQL(srcDS, PAnsiChar(UTF8String(sql)), nil, 'SQLITE');
try
  dstDS := OGR_Dr_CreateDataSource(OGRGetDriverByName('GPKG'),
    PAnsiChar(UTF8String(outPath)), nil);
  OGR_DS_CopyLayer(dstDS, res, 'resultado', nil);
finally
  OGR_DS_ReleaseResultSet(srcDS, res);
  OGRReleaseDataSource(dstDS);
end;
```

## Testing Strategy

- `AnalysisTest.dpr`: aplica buffer/intersección/unión sobre un GeoPackage de
  muestra y verifica que el resultado es un GeoPackage válido y cargable con
  `TVectorLayer.LoadLayers`.
- Manual: ejecutar cada operación en la GUI y ver el resultado como capa nueva.

## Boundaries

- **Always:** liberar resultset y datasources en `try..finally`; usar el nombre
  real de la columna de geometría; validar entrada (distancia > 0; dos capas
  para intersección/unión).
- **Ask first:** nuevas operaciones (clip, dissolve), reproyección, análisis que
  modifiquen las capas originales.
- **Never:** hardcodear rutas de salida o la ruta de `ogr2ogr.exe`; editar
  `gdal-pascal/`.

## Success Criteria

- Buffer de una capa de polígonos produce un GeoPackage con polígonos expandidos.
- Intersección de dos capas superpuestas produce las zonas de solape.
- Unión de dos capas produce la geometría combinada.
- El GeoPackage resultante se carga como capa(s) nueva(s) sin errores.

## Decisiones (resueltas)

- Unión/intersección: el usuario elige **una o dos capas** (disolver una sola o
  operar sobre un par).
- Atributos del resultado: se copian de la fuente (`SELECT *`).
- Salida: el usuario elige ruta/nombre (cuadro de guardado).
