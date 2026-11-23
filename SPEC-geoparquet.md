# Spec: Soporte completo de GeoParquet (lectura y escritura)

## Objetivo

Dar soporte **completo** a GeoParquet (`*.parquet`) en GdalViewer:

1. **Leer** archivos GeoParquet (abrir, dibujar, navegar, identificar, atributos,
   tabla de atributos) — igual que el resto de formatos OGR.
2. **Escribir/exportar** a GeoParquet: exportar una capa cargada y exportar los
   resultados del análisis vectorial a `.parquet`.
3. Mostrar un **aviso explícito** cuando un `.parquet` no tiene columna de
   geometría (Parquet plano, no geo).
4. **Optimizar la identificación** con un índice espacial en memoria, porque el
   driver Parquet no trae índice nativo (hoy identificar es O(N)).

**Usuario objetivo:** quien trabaja con datos vectoriales en GeoParquet (p. ej.
INEGI/IRIS) y necesita inspeccionarlos y re-exportarlos sin pasar por GeoPackage.

**Éxito:** abrir `09Man.parquet` (67 375 manzanas), navegar e identificar al
instante (< 5 ms), y poder exportar una capa o un análisis de vuelta a Parquet.

## Hallazgos verificados (esta máquina)

| Hecho | Evidencia |
|---|---|
| Driver `Parquet` disponible (rw) | `ogrinfo --formats` |
| Lectura ya funciona por OGR | `ParquetProbe` sobre `sample.parquet`: 1 capa, 3 entidades, extensión correcta, geometría/atributos/identificar OK |
| Escritura viable | Binding tiene `OGR_Dr_CreateDataSource`, `OGR_DS_CopyLayer`, `OGR_DS_CreateLayer`, `OGR_F_SetGeometry`, etc. |
| Carga rápida | `09Man.parquet` (67 375 multipolígonos) → **172 ms** |
| Identificar lento (línea base) | `09Man.parquet` → **22.3 ms/clic** (escaneo O(N)) |
| DLLs Arrow empaquetadas | `viewer/Win64/Release/arrow*.dll`, `parquet` deps |

## Alcance

- **Sí:** leer GeoParquet; exportar capa → `.parquet`; análisis → `.parquet`
  (opción de formato); aviso explícito "sin columna de geometría"; índice
  espacial en memoria para identificar.
- **No (esta iteración):** reproyección entre CRS; FlatGeobuf/Arrow; índices
  espaciales persistentes (solo en memoria, por sesión).

## Tech Stack

| Componente | Elección | Notas |
|---|---|---|
| Driver | `Parquet` de GDAL/OGR 3.12 (rw) | Lectura y escritura |
| Lectura | `TVectorLayer` existente | `OGROpen` + `LoadLayers` |
| Escritura | `OGRGetDriverByName('Parquet')` + `OGR_Dr_CreateDataSource` + `OGR_DS_CopyLayer` | Reutiliza el patrón del módulo `analysis` |
| Índice espacial | R-tree en memoria (Delphi puro) | Construido durante la carga sobre los bboxes de las geometrías extraídas |

## Commands

```
# Compilar la app
& "D:\AAB\DELPHI_GDAL\MDM-GDAL\viewer\build.ps1" -Dpr "D:\AAB\DELPHI_GDAL\MDM-GDAL\viewer\GdalViewer.dpr"

# Benchmark de línea base / verificación (identificar sobre 09Man.parquet)
& "D:\AAB\DELPHI_GDAL\MDM-GDAL\viewer\build.ps1" -Dpr "D:\AAB\DELPHI_GDAL\MDM-GDAL\viewer\tests\GeoParquetBench.dpr"
$env:PATH = "D:\OSGeo4w\bin;" + $env:PATH
& "D:\AAB\DELPHI_GDAL\MDM-GDAL\viewer\tests\bin64\GeoParquetBench.exe" "D:\F\IRIS 4.0\2026\GeoParquet\09Man.parquet"
```

## Project Structure

```
MDM-GDAL\
├── SPEC-geoparquet.md            ← esta spec
└── viewer\
    ├── src\
    │   ├── Main.pas              ← filtro *.parquet; Archivo→Guardar como…; aviso sin geometría
    │   ├── SpatialIndex.pas      ← R-tree en memoria (nuevo)
    │   ├── VectorLayer.pas       ← usa el R-tree + detección sin-geometría
    │   ├── GeometryModel.pas     ← helper de bbox para el índice
    │   ├── VectorAnalysis.pas    ← opción de salida Parquet
    │   └── AnalysisForm.pas      ← selector de formato de salida
    ├── tests\
    │   ├── data\sample.parquet   ← muestra (WGS84, 3 entidades)
    │   ├── ParquetProbe.dpr      ← lectura + aviso sin-geometría (aserciones)
    │   ├── GeoParquetBench.dpr   ← benchmark load/identify (antes/después)
    │   └── (nuevo) ExportTest.dpr ← exportar → reabrir → verificar
    └── README.md                 ← documentar GeoParquet + rendimiento
```

## Code Style

Escritura (patrón a seguir, reutiliza el del módulo `analysis`):

```pascal
function ExportLayerToParquet(const Source: TVectorLayer;
  const FileName: string): Boolean;
var
  drv: OGRSFDriverH;
  ds: OGRDataSourceH;
  utf8: UTF8String;
begin
  drv := OGRGetDriverByName(PAnsiChar(UTF8String('Parquet')));
  if drv = nil then
    Exit(False);
  utf8 := UTF8String(FileName);
  ds := OGR_Dr_CreateDataSource(drv, PAnsiChar(utf8), nil);
  if ds = nil then
    Exit(False);
  try
    Result := OGR_DS_CopyLayer(ds, Source.OgrLayer,
      PAnsiChar(UTF8String(Source.LayerName)), nil) = OGRERR_NONE;
  finally
    OGRReleaseDataSource(ds);
  end;
end;
```

Índice espacial: R-tree en memoria sobre los bboxes de `FFeatures` (construido
durante la carga, sin segundo recorrido O(N)). `IdentifyAtWorld` consulta el
R-tree con el bbox del clic y calcula `DistanceToGeometry` solo sobre los
candidatos devueltos.

## Testing Strategy

- **Lectura (consola):** `ParquetProbe` asevera sobre `sample.parquet` (1 capa,
  3 entidades, extensión, atributo `Polígono A`, identificar) → `PARQUET OK`.
- **Sin geometría (consola):** abrir un Parquet plano y aseverar que se detecta
  "sin columna de geometría" (resultado/flag, no excepción).
- **Escritura (consola):** `ExportTest` exporta `sample.parquet` → reabre el
  resultado y compara conteo/extensión/atributos.
- **Rendimiento (consola):** `GeoParquetBench` antes/después sobre `09Man.parquet`.
- **GUI (manual):** abrir `09Man.parquet`, identificar, exportar, abrir el
  resultado; abrir un Parquet plano y ver el aviso.

## Boundaries

- **Always:** usar la vía OGR (no un parser propio); `UTF8ToString`; liberar
  handles en `try..finally`; no romper los tests verdes; el índice en memoria se
  construye durante la carga existente (sin segundo recorrido O(N) extra).
- **Ask first:** reproyección; FlatGeobuf/Arrow; índice persistente en disco.
- **Never:** parser de Parquet a mano; escribir `.parquet` sin metadata geo
  cuando la capa tiene geometría; avisos silenciosos (la ausencia de geometría
  debe ser explícita).

## Success Criteria

1. `Archivo → Abrir` muestra `*.parquet` y abre `09Man.parquet` (67 375 entidades)
   y `09Mun.parquet` correctamente.
2. Identificar en `09Man.parquet` baja de ~22 ms a **< 5 ms** por clic
   (medido con `GeoParquetBench`), sin degradar la carga (< 300 ms).
3. Exportar `09Mun.parquet` (o una capa cargada) a `.parquet` produce un archivo
   que se reabre con el mismo conteo, extensión y atributos.
4. Un análisis (buffer/intersección/unión) puede producir `.parquet` (no solo
   GeoPackage) y el resultado es reabrible.
5. Abrir un `.parquet` sin columna de geometría muestra el aviso explícito
   "sin columna de geometría" y **no** crashea.
6. `ParquetProbe` → `PARQUET OK`; `ExportTest` → `EXPORT OK`; `IntegrationTest` y
   `TransformSmoke` siguen verdes.

## Decisiones cerradas

- **Índice espacial:** R-tree en memoria (no grid uniforme).
- **Exportar UI:** `Archivo → Guardar como…` global (guarda la capa activa o el
  resultado del análisis a `.parquet`, con selector de formato).
