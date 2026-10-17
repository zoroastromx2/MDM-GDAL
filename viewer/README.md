# GdalViewer

Visor de datos vectoriales para Windows, construido con **Delphi (VCL)** y la
librería **GDAL** (API de OGR). Abre un archivo vectorial y lo dibuja en un
canvas con herramientas de navegación (zoom, pan, ajuste a extensión) e
identificación de entidades.

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
& "D:\AAB\DELPHI_GDAL\viewer\build.ps1" -Dpr "D:\AAB\DELPHI_GDAL\viewer\GdalViewer.dpr"
```

`build.ps1` garantiza el BOM UTF-8 de los fuentes (necesario para los literales
con acentos) y compila con `dcc64`. El ejecutable queda en
`viewer\tests\bin64\GdalViewer.exe`.

### IDE (RAD Studio)

Abrir `viewer\GdalViewer.dproj` (o `viewer\GdalViewer.dpr`) y pulsar **F9**
con la plataforma **Win64** seleccionada.

## Ejecutar

GDAL necesita sus DLLs (y las dependencias `proj`, `sqlite3`, etc.) en el PATH:

```powershell
$env:PATH = "D:\OSGeo4w\bin;" + $env:PATH
& "D:\AAB\DELPHI_GDAL\viewer\tests\bin64\GdalViewer.exe"
```

## Uso

| Acción | Resultado |
|---|---|
| `Archivo → Abrir...` | Abre un archivo vectorial (shapefile, GeoJSON, KML, GeoPackage, ...) |
| Rueda del ratón | Acercar/alejar centrado en el cursor |
| Arrastrar | Desplazar (pan) |
| `Ver → Zoom por caja` | Arrastrar un rectángulo para acercar a esa región |
| `Ver → Acercar` / `Alejar` | Zoom + / zoom − |
| `Ver → Ajustar a extensión` | Ver toda la capa |
| Clic sobre una entidad | Muestra sus atributos en un diálogo |

## Cambiar la versión de GDAL

La DLL se fija en la constante `LibName` de `viewer\src\gdal\gdalcore.pas`
(por defecto `'gdal312.dll'`). Para usar otra versión (p. ej. `gdal310.dll`),
cambiar esa constante y recompilar.

## Tests

Compilar y ejecutar con `build.ps1`:

```powershell
# Lógica pura (sin GDAL): transformaciones, modelo geométrico, hit-testing
& "D:\AAB\DELPHI_GDAL\viewer\build.ps1" -Dpr "D:\AAB\DELPHI_GDAL\viewer\tests\TransformSmoke.dpr"
& "D:\AAB\DELPHI_GDAL\viewer\tests\bin64\TransformSmoke.exe"   # -> OK: 27 checks passed

# Integración con GDAL: abre tests\data\sample.geojson y valida conteo/extensión/UTF-8
$env:PATH = "D:\OSGeo4w\bin;" + $env:PATH
& "D:\AAB\DELPHI_GDAL\viewer\build.ps1" -Dpr "D:\AAB\DELPHI_GDAL\viewer\tests\IntegrationTest.dpr"
& "D:\AAB\DELPHI_GDAL\viewer\tests\bin64\IntegrationTest.exe"  # -> INTEGRATION OK
```

## Estructura

```
viewer\
├── GdalViewer.dpr / .dproj   ← proyecto (Win64)
├── build.ps1                 ← compilación + normalización BOM
├── src\
│   ├── Main.pas / .dfm       ← ventana principal (menú, barra de estado)
│   ├── MapCanvas.pas         ← control de dibujo y navegación
│   ├── MapView.pas           ← transformación mundo↔pantalla (pura)
│   ├── VectorLayer.pas       ← apertura OGR y extracción a memoria
│   ├── GeometryModel.pas     ← modelo geométrico + hit-testing (puro)
│   ├── IdentifyForm.pas      ← diálogo de atributos
│   └── gdal\                 ← bindings Pascal (gdalcore, ogr, gdal, osr)
└── tests\
    ├── TransformSmoke.dpr    ← smoke test de lógica pura
    ├── IntegrationTest.dpr   ← test de integración con GDAL
    ├── GdalProbe.dpr         ← probe de versión de GDAL
    └── data\sample.geojson   ← archivo de muestra
```

## Verificación manual (checklist GUI)

- [ ] La app inicia y muestra `GDAL 3.12.2` en la barra de estado.
- [ ] `Archivo → Abrir...` carga `tests\data\sample.geojson` y dibuja un polígono (con agujero), una línea y un punto.
- [ ] La rueda acerca/aleja centrado en el cursor.
- [ ] Arrastrar desplaza el mapa en la dirección correcta.
- [ ] `Ver → Zoom por caja` + arrastrar acerca a la región seleccionada.
- [ ] `Ver → Acercar` / `Alejar` funcionan.
- [ ] `Ver → Ajustar a extensión` restaura la vista completa.
- [ ] Clic en el polígono muestra sus atributos (`name = Polígono A`, `value = 10`).
- [ ] Abrir un archivo inválido muestra un mensaje y no cierra la app.

## Limitaciones (v1)

- Sin reproyección entre sistemas de coordenadas (se dibuja en coordenadas nativas).
- Se muestra la capa 0 del datasource (una sola capa).
- Sin edición de datos ni soporte de datos ráster.
- Solo runtime de 64 bits (el GDAL de OSGeo4W es de 64 bits).
