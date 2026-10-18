# Spec: result-layers — Cargar resultados de análisis como capas nuevas

## Objective

Tras un análisis, cargar el GeoPackage resultante con `TVectorLayer.LoadLayers` y
agregar sus capas al árbol y al canvas (checkbox, color, propiedades, atributos,
identificar), conservando el zoom actual si ya hay capas cargadas.

## Tech Stack

- Reusa `VectorLayer.LoadLayers` y la lógica existente de `Main.OpenFile`.

## Commands

```
powershell -File viewer\build.ps1 -Dpr viewer\GdalViewer.dpr
```

## Project Structure

- `viewer/src/Main.pas` — `AddResultLayers(const FileName, BaseName)`.

## Code Style

- Asignar colores continuando la paleta; nombre de nodo derivado del análisis
  (p. ej. `buffer_<capa>`); reusar `RebuildTree` y `ZoomToFit`/`Invalidate` según
  si el mapa estaba vacío (mismo criterio que `OpenFile`).

## Testing Strategy

- Manual: ejecutar buffer en la GUI y confirmar que la capa resultante aparece
  con checkbox, color, propiedades, atributos e identificar.
- `IntegrationTest` (opcional): cargar el GeoPackage generado por `analysis` y
  verificar conteos.

## Boundaries

- **Always:** reusar `LoadLayers`; asignar color/nombre; no perder capas existentes.
- **Ask first:** sobrescribir archivos existentes; esquema de nombres.
- **Never:** hardcodear rutas; duplicar la lógica de carga.

## Success Criteria

- El resultado aparece como nodo(s) nuevo(s) en el árbol con todas las
  funcionalidades de capa operativas.
- Si el mapa no estaba vacío, no se reencuadra (se conserva el zoom).
- Quitar/ocultar/editar la capa resultante funciona igual que cualquier otra capa.

## Decisiones (resueltas)

- El resultado se agrega como **nodo suelto** (sin nodo archivo padre).
