# Capability Map: OGR-backed GIS (v4)

Rama: `feature/ogr-analysis`

## Modules

| Module id | Responsabilidad | Depende de |
|---|---|---|
| `ogr-source` | Mantener handles OGR vivos (datasource + layer) con dueño compartido entre capas de un mismo archivo; leer atributos sin reabrir; identificar con el índice espacial de OGR; medir la ganancia. | — |
| `analysis` | Ejecutar análisis vectoriales en proceso (SQL espacial: buffer, intersección, unión) sobre las capas cargadas y producir un GeoPackage de resultado. | `ogr-source` |
| `result-layers` | Agregar las capas del resultado del análisis como capas nuevas (reusar carga + árbol + colores). | `analysis` |

## Orden de construcción
`ogr-source` → `analysis` → `result-layers`

## Especificaciones
- [SPEC-ogr-source.md](SPEC-ogr-source.md)
- [SPEC-analysis.md](SPEC-analysis.md)
- [SPEC-result-layers.md](SPEC-result-layers.md)
