# Identidad visual — IET BI Portal

Marca propia del portal, inspirada en el sello del Bachillerato Internacional (círculo, esfera azul con luz, texto en anillo) y en los colores del portal. No reutiliza la "ib" ni el logo del IB, que son marca registrada de la International Baccalaureate Organization; el logo oficial del IB solo se usa donde el Instituto está autorizado (p. ej. el informe CAS).

## Piezas

| Archivo | Uso |
|---|---|
| `svg/logo-sello.svg` · `png/logo-sello-{256,512,1024}.png` | Logo principal: portadas de documentos, encabezados |
| `svg/logo-horizontal.svg` · `png/logo-horizontal@{1x,2x}.png` | Encabezados anchos, pie de página, correos |
| `*-blanco.*` | Sobre fondos oscuros o azules |
| `svg/logo-sello-una-tinta.svg` · `png/logo-sello-una-tinta-*.png` | Impresión en blanco y negro, sellos |
| `svg/isotipo.svg` · `png/isotipo-*.png` | Solo la esfera BI: avatar, ícono |
| `svg/isotipo-app.svg` · `png/isotipo-app-*.png` | Ícono cuadrado con fondo blanco |
| `favicon/` | `favicon.ico` (16/32/48), `favicon.svg`, `favicon-{16,32,48,192,512}.png`, `apple-touch-icon.png` (180) |

Los SVG tienen el texto convertido a trazos: se ven igual sin tener Poppins instalada.

## Colores

| Nombre | Hex | Uso |
|---|---|---|
| Azul portal | `#4099ff` | Color principal (= `--color-primary-blue`) |
| Azul claro | `#8cc4ff` | Inicio del degradado, luces |
| Azul medio | `#1f66b3` | Texto del anillo, enlaces activos |
| Azul noche | `#1b3a6b` | Fin del degradado |
| Tinta | `#29344a` | Texto principal (= `--color-dark-blue`) |
| Dorado | `#ffb64d` | Acento: barra bajo "BI" y puntos del anillo (= `--bs-warning`) |
| Gris texto | `#667085` | Subtítulos |

Degradado de la esfera: `#8cc4ff → #4099ff (42 %) → #1f66b3 (78 %) → #1b3a6b`, de arriba-izquierda a abajo-derecha.

## Tipografía

Poppins (la del portal, licencia OFL): Bold para el monograma, SemiBold para nombres, Medium para subtítulos en mayúsculas con espaciado amplio.

## Reglas de uso

- Dejar alrededor del logo un margen libre de al menos la altura de la barra dorada × 4.
- Tamaño mínimo: sello completo 96 px (2,5 cm impreso); por debajo usar el isotipo o el favicon.
- No deformar, rotar, cambiar colores del degradado ni poner el logo a color sobre fondos azules (usar la versión blanca).

## Favicon en el frontend (Angular)

Copiar `favicon/favicon.ico`, `favicon/favicon.svg` y `favicon/apple-touch-icon.png` a `public/` y en `src/index.html`:

```html
<link rel="icon" href="favicon.ico" sizes="any">
<link rel="icon" type="image/svg+xml" href="favicon.svg">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
```

## Regenerar

`python generar_logo.py <carpeta con Poppins-Bold/SemiBold/Medium.ttf> <carpeta de salida>` (requiere `fonttools`, `pillow` y Microsoft Edge).
