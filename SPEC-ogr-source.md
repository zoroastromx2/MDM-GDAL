# Spec: ogr-source — Handles OGR vivos e identificar con índice espacial

## Objective

Retener los handles OGR (`OGRDataSourceH` + `OGRLayerH`) durante la vida de la
capa para: (a) leer atributos sin reabrir el archivo y (b) identificar usando el
índice espacial de OGR (O(log N)) en lugar del barrido en memoria (O(N)). El
renderizado sigue usando el modelo geométrico en memoria. Se mide la ganancia
antes/después sobre `Aguascalientes.gpkg` (capa de 307,721 puntos).

## Tech Stack

- Delphi (RAD Studio 12 Athens, Win64), VCL.
- Bindings OGR de `viewer/src/gdal/ogr.pas` (GDAL 3.12.2 → `gdal312.dll`).
- APIs clave: `OGROpen`, `OGR_DS_GetLayer`, `OGR_L_GetFeature`,
  `OGR_L_SetSpatialFilterRect`, `OGR_L_ResetReading`, `OGR_F_GetFID`,
  `OGRReleaseDataSource`.

## Commands

```
# Build
powershell -File viewer\build.ps1 -Dpr viewer\GdalViewer.dpr

# Test de integración (OGR real)
powershell -File viewer\build.ps1 -Dpr viewer\tests\IntegrationTest.dpr

# Test puro (GeometryModel / MapView)
powershell -File viewer\build.ps1 -Dpr viewer\tests\TransformSmoke.dpr

# Benchmark de carga
powershell -File viewer\build.ps1 -Dpr viewer\tests\PerfProbe.dpr
```

## Project Structure

- `viewer/src/VectorLayer.pas` — `TVectorLayer` + dueño de datasource compartido.
- `viewer/src/GeometryModel.pas` — modelo puro (sin cambios de API pública).
- `viewer/src/MapCanvas.pas` — `IdentifyAt`/`IdentifyAtLayer` delegan a OGR.
- `viewer/src/Main.pas` — cableado del identificar.
- `viewer/tests/IntegrationTest.dpr`, `viewer/tests/PerfProbe.dpr` — verificación.

## Code Style

- Prefijos `F` para campos, `T` para tipos; cadenas con `UTF8ToString`; handles
  liberados en `try..finally`.
- Ejemplo (dueño compartido con conteo de referencias):

```pascal
type
  TDataSourceOwner = class
  private
    FHandle: OGRDataSourceH;
    FRefCount: Integer;
  public
    procedure AddRef;
    procedure Release;   // cierra el datasource cuando el contador llega a 0
  end;
```

- Identificar con índice espacial: `OGR_L_SetSpatialFilterRect` alrededor del
  clic → `OGR_L_GetNextFeature` para candidatos → distancia exacta contra la
  geometría en memoria (vía mapa FID→índice) → resetear filtro a `nil`.

## Testing Strategy

- `IntegrationTest` verifica que atributos e identificar funcionan tras el cambio
  (mismo comportamiento, backend distinto).
- `PerfProbe` (o un benchmark nuevo de identificar) mide el tiempo de un clic en
  la capa de 307,721 puntos: antes O(N) vs después O(log N).
- `TransformSmoke` sigue verde (modelo puro intacto).

## Boundaries

- **Always:** liberar handles en `try..finally`; refcount correcto del datasource
  compartido; `UTF8ToString` para cadenas; resetear el filtro espacial tras usarlo.
- **Ask first:** cambiar `LibName`; reproyección CRS; cambiar el esquema de FID.
- **Never:** editar `gdal-pascal/` (repo de terceros); filtrar handles; reintroducir
  la reapertura del archivo por cada clic de identificar.

## Success Criteria

- Identificar en la capa de 307,721 puntos baja de O(N) a O(log N) (objetivo:
  < 20 ms por clic).
- Los atributos se leen sin `OGROpen` por clic (un solo `OGROpen` por archivo).
- La memoria del modelo no crece (los handles OGR añaden memoria despreciable).
- `IntegrationTest` y `TransformSmoke` verdes.

## Decisiones (resueltas)

- Mapeo FID → índice: `TDictionary<Int64,Integer>` (robusto; arreglo ordenado
  solo si la memoria lo exige).
- Se mantiene el fallback "todas las capas visibles" cuando no hay capa
  seleccionada.
