# Spec: GdalViewer — Visor de datos vectoriales con GDAL en Delphi

## Objetivo

Construir una aplicación de escritorio Windows en Delphi (VCL) que permita
abrir un archivo de datos vectoriales mediante la librería GDAL (API de OGR) y
visualizarlo en un canvas, con las herramientas básicas de interacción:
acercar, alejar, desplazar y consultar atributos de una entidad.

**Usuario objetivo:** alguien que necesita inspeccionar rápidamente un archivo
vectorial (shapefile, GeoJSON, KML, GeoPackage, etc.) sin abrir un SIG completo.

**Caso de uso principal (historia de usuario):**
> Como usuario, quiero abrir un archivo vectorial, ver sus geometrías dibujadas
> en pantalla, navegar por el mapa (zoom/pan) y hacer clic en una entidad para
> ver sus atributos.

**Éxito:** el usuario abre un archivo, lo ve dibujado correctamente y puede
navegar e identificar entidades sin errores ni cierres inesperados.

## Alcance (lo que SÍ y lo que NO incluye esta versión)

- **Sí:** lectura de una capa vectorial, renderizado 2D (puntos, líneas,
  polígonos), zoom (rueda, caja, botones), pan, ajuste a extensión,
  identificación de entidades (mostrar atributos), manejo de errores amigable.
- **No (v1):** edición/escritura de datos, reproyección sobre la marcha entre
  CRS distintos, mezcla de múltiples capas con CRS distintos, simbología por
  atributo, renderizado ráster, impresión/exportación, temas/estilos complejos.

## Tech Stack

| Componente | Elección | Notas |
|---|---|---|
| Lenguaje / IDE | Delphi RAD Studio 10.4 – 12.x | VCL, plataformas Win32 y Win64 |
| Framework UI | VCL | `TMainMenu`, `TCustomControl` + `TCanvas` (GDI) |
| Librería geoespacial | GDAL 3.x (API C de OGR) | Binarios nativos Windows |
| Bindings Pascal | Adaptación de `gdal-pascal` (Alex Bruy) | Modernizados para GDAL 3.x |
| Renderizado | GDI (`TCanvas.Polyline`, `.Polygon`) | Sin componentes de terceros |

- **Versión de GDAL anclada:** GDAL 3.6 → DLL `gdal306.dll` (constante única
  fácil de cambiar, ver *Open Questions*).
- El proyecto reutiliza el binding existente en `gdal-pascal/units`, copiado y
  modernizado dentro del árbol de la app (no se edita el repo de terceros).

## Commands

Los comandos asumen que el entorno de RAD Studio está cargado (ejecutar
`rsvars.bat` desde la carpeta `bin` de RAD Studio, o abrir el `.dproj` en el IDE).

```
# Build Win32 (Release)
msbuild viewer\GdalViewer.dproj /t:Build /p:Config=Release /p:Platform=Win32

# Build Win64 (Release)
msbuild viewer\GdalViewer.dproj /t:Build /p:Config=Release /p:Platform=Win64

# Compilar solo el smoke test (consola, sin GUI)
msbuild viewer\tests\TransformSmoke.dproj /t:Build /p:Config=Debug /p:Platform=Win32

# Ejecutar el smoke test
viewer\tests\Win32\Debug\TransformSmoke.exe
```

Alternativa desde el IDE: abrir `viewer\GdalViewer.dproj` y pulsar **F9**
(ejecutar) o **Shift+F9** (compilar). Sin RAD Studio instalado no se puede
compilar; el repositorio contiene el código fuente completo y el `.dproj`.

## Project Structure

```
D:\AAB\DELPHI_GDAL\
├── SPEC.md                        ← esta especificación
├── gdal-pascal\                   ← bindings originales (referencia, NO se editan)
│   └── units\  (gdalcore.pas, gdal.pas, ogr.pas, osr.pas)
└── viewer\                        ← aplicación nueva (autocontenida)
    ├── GdalViewer.dpr             ← punto de entrada del proyecto
    ├── GdalViewer.dproj           ← proyecto Delphi
    ├── src\
    │   ├── Main.pas / Main.dfm    ← ventana principal: menú, barra de estado
    │   ├── MapCanvas.pas          ← TMapCanvas (TCustomControl): dibujo + eventos ratón
    │   ├── MapView.pas            ← TMapView: estado de vista y transform mundo↔pantalla
    │   ├── VectorLayer.pas        ← TVectorLayer: abre datasource OGR, extrae a memoria
    │   ├── GeometryUtils.pas      ← conversión OGR geometry → primitivas dibujables
    │   ├── IdentifyForm.pas/.dfm  ← diálogo que muestra atributos de una entidad
    │   └── gdal\                  ← copia modernizada de los bindings
    │       ├── gdalcore.pas       ← LibName → 'gdal306.dll'
    │       ├── ogr.pas
    │       ├── gdal.pas
    │       └── osr.pas
    └── tests\
        └── TransformSmoke.pas     ← smoke test de consola (transform + extracción)
```

**Decisión de arquitectura clave:** al abrir una capa, la app lee **todas** las
entidades con OGR y las convierte a un modelo geométrico propio en memoria
(arrays de puntos/anillos + lista de atributos), y **cierra el datasource**.
El renderizado y la identificación trabajan sobre ese modelo puro en Delphi,
sin depender de handles OGR durante el dibujado. Ventajas: redibujos rápidos,
código de dibujo desacoplado de GDAL, y una lógica de transformación que se
puede probar sin GDAL. Coste: memoria (aceptable para archivos de tamaño normal).

## Code Style

- Prefijos: clases `T`, campos `F`, parámetros sin prefijo. Métodos en
  `PascalCase`, campos privados `camelCase`.
- El modelo de datos usa `record`/`array` simples (`TPointD`, `TRing`,
  `TFeatureGeometry`) en lugar de handles OGR fuera de `VectorLayer`.
- **Cadenas:** OGR devuelve `PAnsiChar` codificado en **UTF-8**; convertirlas
  siempre con `UTF8ToString` (NUNCA con `string(p)` directo).
- Los handles OGR se liberan con su `*_Release`/`*_Destroy` correspondiente en
  `try..finally`.

```pascal
{ TMapView: transformación mundo (coordenadas de la capa) ↔ pantalla }
type
  TPointD = record
    X, Y: Double;
  end;

  TMapView = class
  private
    fCenterWorld: TPointD;   { punto del mundo en el centro del canvas }
    fScale: Double;          { píxeles por unidad del mundo }
  public
    function WorldToScreen(const p: TPointD; out sx, sy: Integer): Boolean;
    function ScreenToWorld(sx, sy: Integer): TPointD;
    procedure ZoomBy(factor: Double; const anchorScreenX, anchorScreenY: Integer);
    procedure PanBy(dxPx, dyPx: Integer);
    procedure FitBounds(const minPt, maxPt: TPointD; wPx, hPx: Integer);
  end;

function TMapView.WorldToScreen(const p: TPointD; out sx, sy: Integer): Boolean;
begin
  sx := Round(fCenterWorld.X + (p.X - fCenterWorld.X) * fScale + ... ); // ver nota
  // Y se invierte: pantalla crece hacia abajo, el mundo (geo) hacia arriba.
  ...
end;
```

> Nota: el snippet es ilustrativo; la fórmula exacta (origen arriba-izquierda vs
> centro, y el flip del eje Y) se fija en `tasks/plan.md`.

- **Buena salida de ejemplo** (extracción de un `wkbLineString` a un anillo):

```pascal
procedure GeometryToRing(geom: OGRGeometryH; var ring: TRing);
var
  i, n: Integer;
begin
  n := OGR_G_GetPointCount(geom);
  SetLength(ring, n);
  for i := 0 to n - 1 do begin
    ring[i].X := OGR_G_GetX(geom, i);
    ring[i].Y := OGR_G_GetY(geom, i);
  end;
end;
```

## Testing Strategy

- **Lógica pura (automatizable sin GUI ni GDAL):** `TMapView` (transformaciones,
  zoom, pan, fit) y `GeometryUtils` sobre datos sintéticos. Se cubre con un
  **smoke test de consola** (`TransformSmoke.pas`) que verifica invariantes:
  ida y vuelta mundo↔pantalla, zoom anclado al cursor, y extracción de
  puntos/líneas/polígonos.
- **Integración con GDAL (manual):** abrir un shapefile y un GeoJSON de muestra,
  verificar conteo de entidades, extensión y dibujado.
- **GUI (checklist manual):** cada herramienta (rueda, caja, botones, pan, fit,
  identificar) tiene su caso en el checklist de verificación de `tasks/todo.md`.
- DUnitX es opcional (no bloquea v1); el smoke test de consola es suficiente
  para la lógica pura.

## Boundaries

- **Always:**
  - Convertir cadenas OGR con `UTF8ToString`.
  - Liberar handles OGR en `try..finally`.
  - Mantener `MapView` y `GeometryUtils` libres de dependencias de GDAL/VCL.
  - Comprobar `Nil` tras cada llamada OGR que devuelva un handle.
  - Documentar el valor de `LibName` y cómo cambiarlo.
- **Ask first:**
  - Cambiar la versión de GDAL anclada (`gdal306.dll` → otra).
  - Añadir dependencias (componentes, DUnitX, otras librerías).
  - Reprojección sobre la marcha o edición de datos (amplía el alcance).
- **Never:**
  - Editar `gdal-pascal/` (repo de terceros); solo se lee como referencia.
  - Incrustar credenciales o rutas absolutas de máquina en el código.
  - Usar `string(pointer)` para convertir cadenas OGR.
  - Leer/escribir archivos fuera del directorio seleccionado por el usuario.

## Success Criteria

1. La app inicia sin errores de GDAL y muestra la versión de GDAL cargada (barra
   de estado / Acerca de).
2. `Archivo → Abrir` permite elegir un archivo vectorial (mínimo shapefile y
   GeoJSON) y carga la capa, mostrando nombre y número de entidades.
3. Al abrir, el canvas dibuja la capa ajustada a la extensión completa; los
   polígonos se rellenan, las líneas y puntos se trazan, todo con un color por
   capa.
4. La rueda del ratón acerca/aleja centrado en el cursor; los botones/menú
   zoom + / zoom − acercan/alejan.
5. El zoom por caja (arrastrar un rectángulo) acerca a la región seleccionada.
6. Arrastrar desplaza (pan) el mapa en la dirección correcta.
7. `Ver → Ajustar a extensión` restaura la vista completa de la capa.
8. Clic en una entidad abre el diálogo de atributos con sus campos y valores.
9. Abrir un archivo inválido o no soportado muestra un mensaje claro y **no**
   provoca una excepción no controlada ni cierra la app.

## Open Questions

1. **Nombre/versión exacta de la DLL de GDAL.** Por defecto anclo `gdal306.dll`
   (GDAL 3.6, build de GISInternals/OSGeo4W). ¿Confirmas GDAL 3.6 o prefieres
   otra versión? ¿Usarás un build con DLLs versionadas (`gdal3xx.dll`) o uno con
   DLL sin versionar (`gdal.dll`, p. ej. conda/vcpkg)? Esto solo cambia la
   constante `LibName` de `gdalcore.pas`.
2. **Ubicación de los bindings modernizados.** Recomiendo copiarlos a
   `viewer/src/gdal/` (no tocar `gdal-pascal/`). ¿De acuerdo, o prefieres que
   modifique `gdal-pascal/units` in place?
3. **Reprojección sobre la marcha.** Confirmo que en v1 se dibuja en las
   coordenadas nativas de la capa (sin transformar entre CRS). ¿Correcto?
