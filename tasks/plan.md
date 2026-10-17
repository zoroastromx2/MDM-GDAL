# Implementation Plan: GdalViewer — Visor vectorial GDAL en Delphi

## Overview

Aplicación VCL de escritorio (Win32/Win64) que abre un archivo vectorial
mediante la API C de OGR (GDAL 3.12) y lo renderiza en un canvas con GDI, con
herramientas de navegación (zoom por rueda, por caja y botones, pan, ajuste a
extensión) e identificación de entidades (mostrar atributos).

La estrategia central: al abrir, se extraen **todas** las entidades a un modelo
geométrico puro en memoria (`GeometryModel`) y se cierra el datasource OGR. El
renderizado, el zoom/pan y el hit-testing trabajan sobre ese modelo Delphi puro,
desacoplado de GDAL. Esto permite probar la lógica sin GDAL y redibujar rápido.

## Environment (verificado en esta máquina)

| Recurso | Ubicación / valor |
|---|---|
| IDE / compilador | RAD Studio 12 Athens (29.0) |
| `dcc32.exe` / `dcc64.exe` | `C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\` |
| DCU Win32 / Win64 | `...\Studio\23.0\lib\win32\release`, `...\lib\win64\release` |
| `rsvars.bat` | `...\Studio\23.0\bin\rsvars.bat` |
| GDAL | OSGeo4W en `D:\OSGeo4w` |
| GDAL activo | 3.12.2 → `gdal312.dll` (en `D:\OSGeo4w\bin`) |
| Dependencias GDAL | `D:\OSGeo4w\bin` (proj_9_4.dll, sqlite3.dll, etc.) |

**Consecuencia:** la compilación y los tests de consola se ejecutan y verifican
en esta máquina con `dcc32`/`dcc64`. La verificación de interacción GUI queda
como checklist manual para el usuario (lanzar el `.exe`).

## Architecture Decisions

1. **Bindings GDAL 3.12:** se copian `gdalcore.pas`/`ogr.pas` (críticos) y
   `gdal.pas`/`osr.pas` (completitud, no compilados en v1) desde `gdal-pascal/`
   a `viewer/src/gdal/`, sin tocar el repo de terceros. Se cambia la única
   constante `LibName` de `'gdal.dll'` a `'gdal312.dll'`.
2. **Compilador objetivo:** RAD Studio 12 Athens; se compila con `dcc64` (Win64),
   opcionalmente `dcc32` (Win32), usando las rutas DCU de `lib\...\release` y la
   opción `-NS` con los unit scope names (`System;Xml;Data;Datasnap;Web;Soap;Winapi;Vcl;...`).
   **Runtime = Win64**: el GDAL de OSGeo4W es 64-bit (`gdal312.dll` → PE `0x8664`);
   un exe Win32 falla con `0xC000007B` al cargar la DLL.
3. **Modelo en memoria:** `TVectorLayer` abre con `OGROpen`, lee la capa 0,
   convierte cada geometría OGR a `TFeatureGeometry` (puntos/líneas/anillos/
   polígonos/multi) y cada entidad a `TFeature` (geometría + atributos), y
   libera el datasource. El resto de la app no toca handles OGR.
4. **Renderizado GDI, un color por capa:** polígonos rellenados (`TCanvas.Polygon`
   con anillos interiores), líneas trazadas (`Polyline`), puntos como marcadores.
5. **Transformación mundo↔pantalla:** `TMapView` puro (centro + escala, eje Y
   invertido). `WorldToScreen`, `ScreenToWorld`, `ZoomBy` anclado al cursor,
   `PanBy`, `FitBounds`.
6. **Cadenas UTF-8:** toda cadena devuelta por OGR (`PAnsiChar`) se convierte con
   `UTF8ToString`; nunca con cast directo a `string`.
7. **Sin reproyección en v1:** se dibuja en las coordenadas nativas de la capa.
8. **Sin edición ni ráster en v1.**

## Task List

El detalle (aceptación, verificación, archivos, dependencias, tamaño) está en
[`tasks/todo.md`](todo.md). Resumen ordenado por dependencia:

### Phase 1 — Fundación (bindings + lógica pura)
- **Task 1:** Copiar y modernizar bindings GDAL + probe de consola que imprime la versión.
- **Task 2:** `GeometryModel.pas` — modelo geométrico puro (puntos, anillos, entidades).
- **Task 3:** `MapView.pas` — transformación mundo↔pantalla + zoom/pan/fit.
- **Checkpoint 1:** probe imprime `GDAL 3.12.2`; unidades puras compilan; smoke test verde.

### Phase 2 — Tubería de datos
- **Task 4:** `VectorLayer.pas` — apertura OGR y extracción a memoria; test de integración.
- **Checkpoint 2:** test de integración abre un archivo real e imprime conteo/extensión correctos.

### Phase 3 — Renderizado y navegación
- **Task 5:** `MapCanvas.pas` — control de dibujo + rueda/pan/caja/botones/fit.
- **Checkpoint 3:** la GUI compila y las herramientas funcionan (manual).

### Phase 4 — Identificación y shell UI
- **Task 6:** hit-testing (puro) + `IdentifyForm` para mostrar atributos.
- **Task 7:** `Main.pas`/`.dfm` + `GdalViewer.dpr`/`.dproj` — menú, barra de estado, apertura.
- **Checkpoint 4:** app completa compila en Win32+Win64; menú completo cableado.

### Phase 5 — Verificación final
- **Task 8:** smoke test consolidado + checklist manual + README de build/run.
- **Checkpoint final:** todos los criterios de éxito de `SPEC.md` cumplidos.

## Risks and Mitigations

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Deriva de API entre el binding GDAL 1.8 y GDAL 3.12 | Alto | Usar solo funciones estables del núcleo OGR; test de integración real que carga `gdal312.dll`. |
| Nombre/versión de DLL incorrecto | Alto | Anclado a `gdal312.dll` (verificado con `gdalinfo --version`); test de integración lo valida. |
| Faltan DLLs dependientes en runtime (proj, sqlite3…) | Medio | Documentar `D:\OSGeo4w\bin` en PATH; el test de integración lo confirma. |
| `.dfm`/`.dproj` escritos a mano con errores | Medio | Verificar con `dcc32`/`dcc64`; iterar hasta compilar limpio. |
| `PAnsiChar`/UTF-8 en Win64 | Bajo | `CPChar = PAnsiChar` + `UTF8ToString`; build Win64 en verificación. |
| Identificadores con caracteres cirílicos en `osr.pas` | Bajo | Corregir al copiar; `osr.pas` no está en la ruta de compilación de v1. |
| Memoria con capas muy grandes | Bajo | Aceptable en v1 (modelo en memoria); documentar como límite. |

## Open Questions

Resueltas en este turno:
1. **GDAL:** 3.12.2 → `gdal312.dll` (OSGeo4W `D:\OSGeo4w`). ✔
2. **Compilador:** RAD Studio 12 Athens (29.0). ✔
3. **Bindings:** copiar a `viewer/src/gdal/` (no editar `gdal-pascal/`). ✔
4. **Reprojección:** fuera de alcance en v1 (coordenadas nativas). ✔

Pendiente menor (no bloquea):
- Formato del archivo de muestra para los tests (propongo generar un GeoJSON
  pequeño en el repo; también se puede usar un shapefile de `D:\OSGeo4w`).
