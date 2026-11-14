"""Genera la identidad visual del IET BI Portal: SVG (texto convertido a trazos) y PNG/ICO.

Uso: python logo.py <carpeta_fuentes> <carpeta_salida>
"""
import math
import subprocess
import sys
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

FUENTES = Path(sys.argv[1])
SALIDA = Path(sys.argv[2])
SALIDA.mkdir(parents=True, exist_ok=True)

# Paleta (tomada del portal: styles.css y sidebar)
AZUL = "#4099ff"        # --color-primary-blue
AZUL_CLARO = "#8cc4ff"
AZUL_MEDIO = "#1f66b3"  # enlaces activos del sidebar
AZUL_NOCHE = "#1b3a6b"
TINTA = "#29344a"       # --color-dark-blue
DORADO = "#ffb64d"      # --bs-warning

fuentes = {p: TTFont(FUENTES / f"Poppins-{p}.ttf") for p in ("Bold", "SemiBold", "Medium")}


def glifo(font, ch):
    cmap = font.getBestCmap()
    nombre = cmap[ord(ch)]
    return nombre, font["hmtx"][nombre][0]


def ruta_glifo(font, nombre, transform):
    gs = font.getGlyphSet()
    pen = SVGPathPen(gs)
    gs[nombre].draw(TransformPen(pen, transform))
    return pen.getCommands()


def texto_linea(texto, peso, size, x, y, tracking=0.0, anchor="start"):
    """Texto horizontal como un <path>. (x, y) = línea base."""
    font = fuentes[peso]
    upm = font["head"].unitsPerEm
    s = size / upm
    ancho = sum(glifo(font, c)[1] * s + tracking * size for c in texto) - tracking * size
    if anchor == "middle":
        x -= ancho / 2
    elif anchor == "end":
        x -= ancho
    d = []
    for c in texto:
        nombre, adv = glifo(font, c)
        d.append(ruta_glifo(font, nombre, (s, 0, 0, -s, x, y)))
        x += adv * s + tracking * size
    return " ".join(d), ancho


def texto_arco(texto, peso, size, cx, cy, r_mid, centro_deg, arriba, tracking=0.08):
    """Texto sobre un círculo. Ángulos en grados, horario desde las 12."""
    font = fuentes[peso]
    upm = font["head"].unitsPerEm
    s = size / upm
    cap = font["OS/2"].sCapHeight * s
    avances = [glifo(font, c)[1] * s + tracking * size for c in texto]
    total = sum(avances) - tracking * size
    span = math.degrees(total / r_mid)
    d = []
    acum = 0.0
    for c, adv in zip(texto, avances):
        nombre, a = glifo(font, c)
        a *= s
        medio = acum + a / 2
        acum += adv
        if c == " ":
            continue
        if arriba:
            th = centro_deg - span / 2 + math.degrees(medio / r_mid)
            r = r_mid - cap / 2  # línea base hacia adentro, letras hacia afuera
            rad = math.radians(th)
            # base del glifo centrada en el ángulo, "arriba" del glifo hacia afuera
            ux, uy = math.sin(rad), -math.cos(rad)      # radial hacia afuera
            tx, ty = math.cos(rad), math.sin(rad)       # tangente (sentido horario)
            bx, by = cx + ux * r - tx * a / 2, cy + uy * r - ty * a / 2
            # x del glifo -> tangente; y del glifo (arriba) -> radial afuera
            m = (tx * s, ty * s, ux * s, uy * s, bx, by)
        else:
            th = centro_deg + span / 2 - math.degrees(medio / r_mid)
            r = r_mid + cap / 2  # línea base hacia afuera, letras hacia el centro
            rad = math.radians(th)
            ux, uy = -math.sin(rad), math.cos(rad)      # radial hacia adentro
            tx, ty = -math.cos(rad), -math.sin(rad)     # tangente antihoraria (lectura izq->der)
            px, py = cx + math.sin(rad) * r, cy - math.cos(rad) * r
            bx, by = px - tx * a / 2, py - ty * a / 2
            m = (tx * s, ty * s, ux * s, uy * s, bx, by)
        # fontTools: (xx, xy, yx, yy, dx, dy) aplica x' = xx*x + yx*y + dx
        xx, xy, yx, yy, dx, dy = m
        d.append(ruta_glifo(font, nombre, (xx, xy, yx, yy, dx, dy)))
    return " ".join(d), span


def defs(prefijo, cx, cy, R):
    return f"""
  <defs>
    <linearGradient id="{prefijo}esfera" x1="{cx-R*0.7:.1f}" y1="{cy-R*0.8:.1f}" x2="{cx+R*0.7:.1f}" y2="{cy+R*0.9:.1f}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="{AZUL_CLARO}"/>
      <stop offset="0.42" stop-color="{AZUL}"/>
      <stop offset="0.78" stop-color="{AZUL_MEDIO}"/>
      <stop offset="1" stop-color="{AZUL_NOCHE}"/>
    </linearGradient>
    <clipPath id="{prefijo}clip"><circle cx="{cx}" cy="{cy}" r="{R}"/></clipPath>
  </defs>"""


def esfera(prefijo, cx, cy, R, mono=None, brillo=True):
    """Esfera con el monograma BI. mono = color plano (versiones de una tinta)."""
    relleno = mono or f"url(#{prefijo}esfera)"
    partes = [f'<circle cx="{cx}" cy="{cy}" r="{R}" fill="{relleno}"/>']
    if brillo and not mono:
        # media luna de luz arriba a la izquierda + barrido inferior
        o = R * 0.16
        partes.append(
            f'<path clip-path="url(#{prefijo}clip)" fill="#fff" fill-opacity="0.22" fill-rule="evenodd" '
            f'd="M {cx-R} {cy} a {R} {R} 0 1 0 {2*R} 0 a {R} {R} 0 1 0 {-2*R} 0 Z '
            f'M {cx-R+o} {cy+o} a {R} {R} 0 1 0 {2*R} 0 a {R} {R} 0 1 0 {-2*R} 0 Z"/>')
        partes.append(
            f'<ellipse clip-path="url(#{prefijo}clip)" cx="{cx+R*0.25}" cy="{cy+R*1.05}" rx="{R*1.1}" ry="{R*0.42}" '
            f'fill="{AZUL_NOCHE}" fill-opacity="0.25"/>')
    # Monograma BI
    size = R * 1.02
    d, ancho = texto_linea("BI", "Bold", size, 0, 0, tracking=0.02)
    cap = fuentes["Bold"]["OS/2"].sCapHeight * size / fuentes["Bold"]["head"].unitsPerEm
    x0 = cx - ancho / 2 - R * 0.02
    y0 = cy + cap / 2 - R * 0.04
    d, _ = texto_linea("BI", "Bold", size, x0, y0, tracking=0.02)
    color_letras = "#fff" if mono != "#fff" else TINTA
    partes.append(f'<path fill="{color_letras}" d="{d}"/>')
    # Acento: barra dorada bajo el monograma (línea de "graduación")
    bw = ancho * 0.62
    partes.append(f'<rect x="{cx-bw/2-R*0.02:.1f}" y="{y0+R*0.13:.1f}" width="{bw:.1f}" height="{R*0.07:.1f}" rx="{R*0.035:.1f}" '
                  f'fill="{DORADO if not mono else color_letras}"/>')
    return "\n  ".join(partes)


def svg(w, h, cuerpo, titulo):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img" aria-label="{titulo}">\n'
            f'  <title>{titulo}</title>{cuerpo}\n</svg>\n')


def sello(texto_color, mono=None, fondo=None):
    W = 512
    c = W / 2
    R = 150
    r_mid = 203
    size = 26
    sup, span_sup = texto_arco("INSTITUTO DE EDUCACIÓN DR. CLODOMIRO PICADO", "SemiBold", size, c, c, r_mid, 0, True, 0.10)
    inf, span_inf = texto_arco("IET BI PORTAL", "SemiBold", size, c, c, r_mid, 180, False, 0.18)
    # puntos separadores a mitad del hueco entre ambos textos
    hueco_der = (span_sup / 2 + (180 - span_inf / 2)) / 2
    puntos = ""
    color_punto = DORADO if not mono else texto_color
    for th in (hueco_der, 360 - hueco_der):
        rad = math.radians(th)
        puntos += f'<circle cx="{c+math.sin(rad)*r_mid:.1f}" cy="{c-math.cos(rad)*r_mid:.1f}" r="5" fill="{color_punto}"/>'
    cuerpo = defs("s", c, c, R)
    if fondo:
        cuerpo += f'\n  <circle cx="{c}" cy="{c}" r="{W/2}" fill="{fondo}"/>'
    cuerpo += f'\n  <path fill="{texto_color}" d="{sup} {inf}"/>\n  {puntos}\n  ' + esfera("s", c, c, R, mono)
    return svg(W, W, cuerpo, "IET BI Portal — Instituto de Educación Dr. Clodomiro Picado")


def isotipo(mono=None, fondo_redondeado=None):
    W = 512
    c = W / 2
    cuerpo = defs("i", c, c, 240)
    if fondo_redondeado:
        cuerpo += f'\n  <rect width="{W}" height="{W}" rx="112" fill="{fondo_redondeado}"/>'
        cuerpo += "\n  " + esfera("i", c, c, 200, mono)
    else:
        cuerpo += "\n  " + esfera("i", c, c, 248, mono)
    return svg(W, W, cuerpo, "IET BI Portal")


def horizontal(color_nombre, color_sub, mono=None):
    H = 200
    R = 88
    cx, cy = 100, 100
    d1, a1 = texto_linea("IET BI Portal", "SemiBold", 76, 214, 104, tracking=-0.01)
    d2, a2 = texto_linea("INSTITUTO DE EDUCACIÓN DR. CLODOMIRO PICADO", "Medium", 19.5, 217, 146, tracking=0.10)
    W = int(214 + max(a1, a2) + 24)
    cuerpo = defs("h", cx, cy, R)
    cuerpo += "\n  " + esfera("h", cx, cy, R, mono)
    cuerpo += f'\n  <path fill="{color_nombre}" d="{d1}"/>'
    cuerpo += f'\n  <rect x="217" y="118" width="64" height="4" rx="2" fill="{DORADO if not mono else color_nombre}"/>'
    cuerpo += f'\n  <path fill="{color_sub}" d="{d2}"/>'
    return svg(W, H, cuerpo, "IET BI Portal — Instituto de Educación Dr. Clodomiro Picado"), W, H


archivos = {
    "logo-sello.svg": (sello(AZUL_MEDIO), 512, 512),
    "logo-sello-blanco.svg": (sello("#fff", mono="#fff"), 512, 512),
    "logo-sello-una-tinta.svg": (sello(TINTA, mono=TINTA), 512, 512),
    "isotipo.svg": (isotipo(), 512, 512),
    "isotipo-app.svg": (isotipo(fondo_redondeado="#ffffff"), 512, 512),
}
svg_h, wh, hh = horizontal(TINTA, "#667085")
archivos["logo-horizontal.svg"] = (svg_h, wh, hh)
svg_hb, _, _ = horizontal("#fff", "#c9d6ea", mono="#fff")
archivos["logo-horizontal-blanco.svg"] = (svg_hb, wh, hh)

for nombre, (contenido, _, _) in archivos.items():
    (SALIDA / "svg").mkdir(exist_ok=True)
    (SALIDA / "svg" / nombre).write_text(contenido, encoding="utf-8")

# --- Render a PNG con Edge headless (fondo transparente) ---
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
tmp = SALIDA / "_render"
tmp.mkdir(exist_ok=True)


def render(nombre_svg, w, h, escala, destino):
    html = tmp / (nombre_svg + ".html")
    contenido = (SALIDA / "svg" / nombre_svg).read_text(encoding="utf-8")
    contenido = contenido.replace(f'width="{w}" height="{h}"', f'width="{w*escala}" height="{h*escala}"', 1)
    html.write_text(f"<!doctype html><html><body style='margin:0;background:transparent'>{contenido}</body></html>", encoding="utf-8")
    import time
    for intento in range(6):
        perfil = (tmp / f"perfil-{destino.stem}-{intento}").resolve()
        subprocess.run([EDGE, "--headless", "--disable-gpu", f"--user-data-dir={perfil}", "--hide-scrollbars",
                        "--default-background-color=00000000", f"--window-size={w*escala},{h*escala}",
                        f"--screenshot={destino.resolve()}", html.resolve().as_uri()], capture_output=True, timeout=90)
        for _ in range(20):
            if destino.exists():
                return
            time.sleep(0.5)
    raise RuntimeError(f"Edge no generó {destino}")


from PIL import Image  # noqa: E402

png = SALIDA / "png"
png.mkdir(exist_ok=True)
for nombre, (_, w, h) in archivos.items():
    base = nombre[:-4]
    grande = png / f"{base}@4x.png"
    render(nombre, w, h, 4, grande)
    img = Image.open(grande).convert("RGBA")
    if nombre.startswith("logo-horizontal"):
        tamanos = {"@1x": (w, h), "@2x": (w * 2, h * 2), "@4x": None}
    else:
        tamanos = {"-1024": (1024, 1024), "-512": (512, 512), "-256": (256, 256), "@4x": None}
    for suf, t in tamanos.items():
        if t is None:
            continue
        img.resize(t, Image.LANCZOS).save(png / f"{base}{suf}.png", optimize=True)
    if nombre.startswith("logo-horizontal"):
        grande.unlink()
    else:
        grande.unlink()

# --- Favicon ---
fav = SALIDA / "favicon"
fav.mkdir(exist_ok=True)
iso = Image.open(png / "isotipo-1024.png").convert("RGBA")
for t in (16, 32, 48, 192, 512):
    iso.resize((t, t), Image.LANCZOS).save(fav / f"favicon-{t}.png", optimize=True)
iso.resize((48, 48), Image.LANCZOS).save(fav / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
app = Image.open(png / "isotipo-app-1024.png").convert("RGBA")
app.resize((180, 180), Image.LANCZOS).save(fav / "apple-touch-icon.png", optimize=True)
(fav / "favicon.svg").write_text(archivos["isotipo.svg"][0], encoding="utf-8")

import shutil
shutil.rmtree(tmp, ignore_errors=True)
for f in []:
    f.unlink()
print("listo")
