# Tareas — GdalViewer

Estado: pendiente de aprobación del plan. Cada tarea sigue la estructura
Descripción / Criterios de aceptación / Verificación / Dependencias / Archivos.

---

## Task 1: Copiar y modernizar los bindings GDAL

**Description:** Copiar `gdalcore.pas`, `ogr.pas`, `gdal.pas`, `osr.pas` desde
`gdal-pascal/units/` a `viewer/src/gdal/`. Cambiar la constante `LibName` de
`'gdal.dll'` a `'gdal312.dll'` en `gdalcore.pas`. Corregir los identificadores
con carácter cirílico (`PCPСhar`/`CPСhar` → `PCPChar`/`CPChar`) en `osr.pas`.
Crear un probe de consola (`GdalProbe.dpr`) que llame `GDALVersionInfo('--version')`.

**Acceptance criteria:**
- [ ] `LibName = 'gdal312.dll'` es la única constante de DLL y `ogr.pas` la referencia.
- [ ] No quedan caracteres cirílicos en los identificadores de los bindings.
- [ ] El probe compila (Win32 y Win64) e imprime `GDAL 3.12.2` al ejecutarse con `D:\OSGeo4w\bin` en PATH.

**Verification:**
- [ ] `dcc32` compila `GdalProbe.dpr` sin errores; `dcc64` idem.
- [ ] Ejecutar `GdalProbe.exe` con `D:\OSGeo4w\bin` en PATH → imprime versión 3.12.2.

**Dependencies:** None

**Files:** `viewer/src/gdal/gdalcore.pas`, `ogr.pas`, `gdal.pas`, `osr.pas`; `viewer/tests/GdalProbe.dpr`

**Size:** S (2-4 archivos)

---

## Task 2: Modelo geométrico puro (`GeometryModel.pas`)

**Description:** Tipos puros sin dependencias de VCL/GDAL: `TPointD`, `TRing`,
`TGeometryKind` (Point/Line/Polygon/MultiPoint/MultiLine/MultiPolygon),
`TFeatureGeometry` (kind + partes/anillos), `TFeature` (geometría + lista de
atributos nombre/valor), y `GeometryBounds` (mín/máx de un `TFeatureGeometry`).

**Acceptance criteria:**
- [ ] La unidad no usa `Windows`, `Vcl.*`, ni `gdalcore`/`ogr`.
- [ ] `GeometryBounds` devuelve el rectángulo mínimo envolvente correcto para un punto, una línea y un polígono.

**Verification:**
- [ ] Compila standalone con `dcc32`.
- [ ] Cubierto por aserciones en `TransformSmoke` (Task 8).

**Dependencies:** None

**Files:** `viewer/src/GeometryModel.pas`

**Size:** S (1 archivo)

---

## Task 3: Transformación mundo↔pantalla (`MapView.pas`)

**Description:** `TMapView` con centro del mundo (`TPointD`) y escala
(píxeles/unidad). Métodos `WorldToScreen`/`ScreenToWorld` (eje Y invertido),
`ZoomBy(factor, anchorX, anchorY)` que mantiene fijo el punto bajo el cursor,
`PanBy(dxPx, dyPx)`, `FitBounds(minPt, maxPt, anchoPx, altoPx)`.

**Acceptance criteria:**
- [ ] `WorldToScreen` → `ScreenToWorld` es ida y vuelta (error < 1 px).
- [ ] `ZoomBy` mantiene el punto ancla fijo en pantalla.
- [ ] `FitBounds` hace que el bounding box ocupe el viewport (con margen).

**Verification:**
- [ ] Compila con `dcc32`.
- [ ] Aserciones de invariantes en `TransformSmoke` (Task 8) pasan.

**Dependencies:** Task 2 (usa `TPointD`)

**Files:** `viewer/src/MapView.pas`

**Size:** S (1 archivo)

---

## Checkpoint: después de Tasks 1-3
- [ ] `GdalProbe.exe` imprime `GDAL 3.12.2`.
- [ ] `GeometryModel.pas` y `MapView.pas` compilan sin VCL/GDAL.
- [ ] Revisar con el usuario antes de continuar.

---

## Task 4: Apertura de capa y extracción (`VectorLayer.pas`)

**Description:** `TVectorLayer` que abre el datasource con `OGROpen`, obtiene la
capa 0, lee su extensión (`OGR_L_GetExtent`) y su definición de campos, itera
entidades (`OGR_L_GetNextFeature`) y convierte cada geometría a
`TFeatureGeometry` (recursivo: punto, línea, anillo de polígono, multi*) y los
atributos a `TFeature`. Libera el datasource al final (`try..finally`). Helper de
conversión UTF-8 para cadenas. Generar un GeoJSON de muestra en el repo.

**Acceptance criteria:**
- [ ] Abre el GeoJSON de muestra; el conteo de entidades y la extensión coinciden con `ogrinfo`.
- [ ] Polígonos/líneas/puntos se convierten al modelo sin perder anillos ni partes.
- [ ] El datasource se libera (sin fugas) incluso ante error.

**Verification:**
- [ ] Test de integración de consola (`IntegrationTest.dpr`) abre el archivo de muestra, imprime conteo + extensión y termina limpio.
- [ ] Ejecutar con `D:\OSGeo4w\bin` en PATH; comparar contra `ogrinfo -so` del mismo archivo.

**Dependencies:** Task 1 (bindings), Task 2 (modelo)

**Files:** `viewer/src/VectorLayer.pas`, `viewer/tests/IntegrationTest.dpr`, `viewer/tests/data/sample.geojson`

**Size:** M (3-4 archivos)

---

## Checkpoint: después de Task 4
- [ ] El test de integración abre un archivo real y reporta datos correctos.
- [ ] Revisar con el usuario antes de continuar.

---

## Task 5: Canvas de dibujo y navegación (`MapCanvas.pas`)

**Description:** `TMapCanvas` (descendiente de `TCustomControl`) que en `Paint`
dibuja cada `TFeatureGeometry` con GDI (polígonos rellenos con anillos,
`Polyline` para líneas, marcador para puntos), usando un color por capa. Maneja
eventos de ratón: rueda = zoom anclado al cursor; arrastrar = pan; arrastrar con
tecla de caja = zoom por rectángulo; métodos `ZoomIn`/`ZoomOut`/`ZoomToFit`.

**Acceptance criteria:**
- [ ] Al cargar una capa se dibuja ajustada a la extensión completa.
- [ ] La rueda acerca/aleja centrado en el cursor; arrastrar desplaza; la caja acerca a la región; `ZoomToFit` restaura la vista.
- [ ] El dibujado no deja artefactos al redibujar (doble buffer / `Invalidate` correcto).

**Verification:**
- [ ] Compila con `dcc32`/`dcc64`.
- [ ] Checklist manual (lanzar GUI): rueda, pan, caja, botones, fit.

**Dependencies:** Task 2 (modelo), Task 3 (mapview), Task 4 (datos)

**Files:** `viewer/src/MapCanvas.pas`

**Size:** M (1-2 archivos)

---

## Task 6: Hit-testing e identificación (`IdentifyForm`)

**Description:** Funciones puras de hit-test en `GeometryModel` (punto-en-polígono,
distancia punto-a-segmento, distancia a punto) para seleccionar la entidad más
cercana a un clic dentro de una tolerancia. `TIdentifyForm` que muestra los
atributos (nombre/valor) de la entidad seleccionada en una grilla.

**Acceptance criteria:**
- [ ] El clic selecciona la entidad más cercana dentro de la tolerancia.
- [ ] El diálogo muestra los campos y valores correctos de la entidad.
- [ ] El hit-test es puro (sin VCL/GDAL) y verificable por aserciones.

**Verification:**
- [ ] Compila con `dcc32`.
- [ ] Aserciones de hit-test en `TransformSmoke` (Task 8).
- [ ] Checklist manual: clic en una entidad → atributos correctos.

**Dependencies:** Task 2, Task 5

**Files:** `viewer/src/IdentifyForm.pas`, `viewer/src/IdentifyForm.dfm` (+ hit-test en `GeometryModel.pas`)

**Size:** S-M (2-3 archivos)

---

## Task 7: Ventana principal con menú (`Main` + proyecto)

**Description:** `Main.pas`/`Main.dfm` con `TMainMenu`: **Archivo** (Abrir…,
Salir), **Ver** (Acercar, Alejar, Ajustar a extensión, Zoom por caja
[conmutable]), **Ayuda** (Acerca de). Barra de estado con versión de GDAL,
nombre de capa, nº de entidades y coordenadas del cursor. `TOpenDialog` para
elegir archivo; carga con `TVectorLayer` + `Fit`; manejo de errores con
`try..except` → `ShowMessage`. Crear `GdalViewer.dpr` y `GdalViewer.dproj`.

**Acceptance criteria:**
- [ ] La app compila como VCL GUI en Win32 y Win64.
- [ ] Todos los ítems de menú están cableados a sus acciones.
- [ ] Abrir un archivo inválido muestra un mensaje y no cierra la app.

**Verification:**
- [ ] `dcc32` y `dcc64` compilan sin errores.
- [ ] Checklist manual: abrir, navegar, identificar, abrir archivo inválido.

**Dependencies:** Task 4, Task 5, Task 6

**Files:** `viewer/src/Main.pas`, `viewer/src/Main.dfm`, `viewer/GdalViewer.dpr`, `viewer/GdalViewer.dproj`

**Size:** M (3-4 archivos)

---

## Checkpoint: después de Tasks 5-7
- [ ] La GUI compila en Win32+Win64.
- [ ] Checklist manual completo: todas las herramientas y el menú funcionan.

---

## Task 8: Smoke test consolidado, checklist y README

**Description:** Finalizar `TransformSmoke.dpr` (consola) con aserciones de
`MapView` (ida/vuelta, zoom anclado, fit), `GeometryModel` (bounds, hit-test).
Ejecutarlo y registrar resultado. Escribir `viewer/README.md` con build/run
(PATH a `D:\OSGeo4w\bin`, cómo cambiar `LibName`) y el checklist manual.

**Acceptance criteria:**
- [ ] `TransformSmoke.exe` se ejecuta y todas las aserciones pasan.
- [ ] El README documenta compilación, ejecución, requisitos de GDAL y límites.

**Verification:**
- [ ] Ejecutar `TransformSmoke.exe` → salida "OK" / sin fallos.
- [ ] Revisión del README y del checklist.

**Dependencies:** Task 2, Task 3, Task 6

**Files:** `viewer/tests/TransformSmoke.dpr`, `viewer/README.md`

**Size:** S-M (2 archivos)

---

## Checkpoint final
- [ ] Todos los criterios de éxito de `SPEC.md` se cumplen.
- [ ] App compila (Win32/Win64), tests de consola verdes, checklist manual aprobado.
