# MDM-GDAL (GdalViewer)

Visor de datos vectoriales para Windows, construido con **Delphi (VCL)** y la
librería **GDAL** (API de OGR). Abre uno o varios archivos vectoriales, los
dibuja en un canvas con navegación (zoom, pan, ajuste a extensión), identifica
entidades, muestra tablas de atributos y ejecuta análisis vectoriales en proceso
(buffer, intersección, unión). Soporta **GeoParquet** en lectura y escritura.

## Requisitos

| Componente | Versión probada | Notas |
|---|---|---|
| RAD Studio | 12 Athens (compilador 36.0) | VCL, plataforma Win64 |
| GDAL (OSGeo4W) | 3.12.2 | DLL `gdal312.dll` de **64 bits** en `D:\OSGeo4w\bin` |
| Sistema operativo | Windows 64 bits | — |

> El GDAL de OSGeo4W es de 64 bits, por eso el ejecutable debe ser **Win64**.
> Un exe Win32 falla al cargar la DLL con `0xC000007B`.

## Compilar

### Línea de comandos (PowerShell)

```powershell
& "D:\AAB\DELPHI_GDAL\MDM-GDAL\viewer\build.ps1" -Dpr "D:\AAB\DELPHI_GDAL\MDM-GDAL\viewer\GdalViewer.dpr"
```

`build.ps1` garantiza el BOM UTF-8 de los fuentes y compila con `dcc64`. El
ejecutable queda en `viewer\tests\bin64\GdalViewer.exe`.

### IDE (RAD Studio)

Abrir `viewer\GdalViewer.dproj` (o `viewer\GdalViewer.dpr`) y pulsar **F9** con
la plataforma **Win64** seleccionada.

## Ejecutar

GDAL necesita sus DLLs en el PATH:

```powershell
$env:PATH = "D:\OSGeo4w\bin;" + $env:PATH
& "D:\AAB\DELPHI_GDAL\MDM-GDAL\viewer\tests\bin64\GdalViewer.exe"
```

## Uso

| Acción | Resultado |
|---|---|
| `Archivo → Abrir...` | Abre archivos vectoriales (shapefile, GeoJSON, KML, GeoPackage, **GeoParquet**, ...) |
| `Archivo → Guardar como...` | Exporta la capa seleccionada a **GeoParquet** (`.parquet`) |
| `Análisis → Buffer / Intersección / Unión` | Análisis vectorial; salida en GeoPackage o GeoParquet |
| Rueda del ratón | Acercar/alejar centrado en el cursor |
| Arrastrar | Desplazar (pan) |
| `Ver → Zoom por caja` | Arrastrar un rectángulo para acercar a esa región |
| `Ver → Acercar` / `Alejar` | Zoom + / zoom − |
| `Ver → Ajustar a extensión` | Ver todas las capas |
| Clic sobre una entidad | Muestra sus atributos |
| Doble clic en el árbol | Edita estilo de la capa |

## GeoParquet

- **Lectura:** los archivos `.parquet` se abren con el driver `Parquet` de OGR
  (no hay lector propio). El filtro de apertura incluye `*.parquet`.
- **Escritura:** `Archivo → Guardar como...` y el análisis exportan a `.parquet`
  vía `OGR_DS_CopyLayer` al driver `Parquet`.
- **Sin geometría:** un `.parquet` plano (sin columna de geometría) muestra el
  aviso "Sin columna de geometría" y carga los atributos sin dibujar nada.
- **Identificación rápida:** como el driver Parquet no trae índice espacial, las
  entidades se indexan en un **R-tree en memoria** (`SpatialIndex.pas`) durante la
  carga. Sobre `09Man.parquet` (67 375 multipolígonos): identificar pasó de
  **~22 ms a < 1 ms** por clic, con carga en ~177 ms.

## Cambiar la versión de GDAL

La DLL se fija en la constante `LibName` de `viewer\src\gdal\gdalcore.pas`
(por defecto `'gdal312.dll'`). Cambiarla y recompilar.

## Tests

```powershell
$root = "D:\AAB\DELPHI_GDAL\MDM-GDAL"
$env:PATH = "D:\OSGeo4w\bin;" + $env:PATH

# Lógica pura (sin GDAL): transformaciones, modelo, hit-testing, R-tree
& "$root\viewer\build.ps1" -Dpr "$root\viewer\tests\TransformSmoke.dpr"
& "$root\viewer\tests\bin64\TransformSmoke.exe"     # -> OK: 36 checks passed

# Integración OGR (sample.geojson)
& "$root\viewer\build.ps1" -Dpr "$root\viewer\tests\IntegrationTest.dpr"
& "$root\viewer\tests\bin64\IntegrationTest.exe"    # -> INTEGRATION OK

# GeoParquet: lectura + detección sin geometría
& "$root\viewer\build.ps1" -Dpr "$root\viewer\tests\ParquetProbe.dpr"
& "$root\viewer\tests\bin64\ParquetProbe.exe"       # -> PARQUET OK

# GeoParquet: exportar -> reabrir -> comparar
& "$root\viewer\build.ps1" -Dpr "$root\viewer\tests\ExportTest.dpr"
& "$root\viewer\tests\bin64\ExportTest.exe"         # -> EXPORT OK

# Análisis vectorial (GPKG)
& "$root\viewer\build.ps1" -Dpr "$root\viewer\tests\AnalysisTest.dpr"
& "$root\viewer\tests\bin64\AnalysisTest.exe"       # -> ANALYSIS OK

# Benchmark de identificar (R-tree)
& "$root\viewer\build.ps1" -Dpr "$root\viewer\tests\GeoParquetBench.dpr"
& "$root\viewer\tests\bin64\GeoParquetBench.exe" "D:\F\IRIS 4.0\2026\GeoParquet\09Man.parquet"
```

## Estructura

```
viewer\
├── GdalViewer.dpr / .dproj   ← proyecto (Win64)
├── build.ps1                 ← compilación + normalización BOM
├── src\
│   ├── Main.pas / .dfm       ← ventana principal (menú, árbol de capas)
│   ├── MapCanvas.pas         ← control de dibujo y navegación (multi-capa)
│   ├── MapView.pas           ← transformación mundo↔pantalla (pura)
│   ├── VectorLayer.pas       ← apertura OGR + extracción + R-tree
│   ├── SpatialIndex.pas      ← R-tree en memoria (puro)
│   ├── GeometryModel.pas     ← modelo geométrico + hit-testing (puro)
│   ├── VectorAnalysis.pas    ← buffer/intersección/unión + exportar Parquet
│   ├── AnalysisForm.pas      ← diálogo de análisis
│   ├── IdentifyForm.pas      ← diálogo de atributos de una entidad
│   ├── AttributesForm.pas    ← tabla de atributos de la capa
│   ├── LayerStyleForm.pas    ← diálogo de estilo de capa
│   └── gdal\                 ← bindings Pascal (gdalcore, ogr, gdal, osr)
└── tests\
    ├── TransformSmoke.dpr    ← lógica pura (incluye R-tree)
    ├── IntegrationTest.dpr   ← integración OGR
    ├── ParquetProbe.dpr      ← GeoParquet (lectura + sin geometría)
    ├── ExportTest.dpr        ← GeoParquet (exportar → reabrir)
    ├── GeoParquetBench.dpr   ← benchmark load/identify
    ├── AnalysisTest.dpr      ← análisis vectorial
    └── data\                 ← muestras (sample.geojson/.parquet, plain.parquet, ...)
```

## Verificación manual (checklist GUI)

- [ ] La app inicia y muestra la versión de GDAL en la barra de estado.
- [ ] `Archivo → Abrir...` carga `sample.geojson` y `sample.parquet` (polígono con agujero, línea, punto).
- [ ] Abrir `plain.parquet` muestra el aviso "Sin columna de geometría".
- [ ] `Archivo → Guardar como...` exporta la capa seleccionada a `.parquet` y se puede reabrir.
- [ ] `Análisis → Buffer` con formato GeoParquet genera un `.parquet` reabrible.
- [ ] La rueda acerca/aleja; arrastrar desplaza; caja/botones/fit funcionan.
- [ ] Clic en una entidad muestra sus atributos.
- [ ] Abrir un archivo inválido muestra un mensaje y no cierra la app.

## Limitaciones

- Sin reproyección entre sistemas de coordenadas (se dibuja en coordenadas nativas).
- Sin edición de datos ni soporte de datos ráster.
- Solo runtime de 64 bits (el GDAL de OSGeo4W es de 64 bits).
