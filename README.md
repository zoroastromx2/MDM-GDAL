# Spec: MDMViewer — Visor de datos vectoriales con GDAL en Delphi

## Objetivo

Construir una aplicación de escritorio Windows en Delphi (VCL) que permita
abrir un archivo de datos vectoriales mediante la librería GDAL (API de OGR) y
visualizarlo en un canvas, con las herramientas básicas de interacción:
acercar, alejar, desplazar y consultar atributos de una entidad.

**Usuario objetivo:** alguien que necesita inspeccionar rápidamente un archivo
vectorial (shapefile, GeoJSON, KML, GeoPackage, etc.) sin abrir un SIG completo.
