"""Generate scalable silhouettes from the approved icon crops.

Optional build-time tools: Pillow and vtracer==0.6.15 (not app dependencies).
Run from vendor/: python3 tool/trace_owner_icons.py
The supplied brand mark and product photography are deliberately not traced.
"""
from pathlib import Path
import re
from PIL import Image
import vtracer

ROOT = Path(__file__).resolve().parents[1] / 'assets/owner'
NAMES = ('back', 'plus', 'product-plus', 'chevron', 'vendor-chevron', 'down',
         'bell', 'store', 'warning', 'reports', 'manage', 'home', 'nav-store',
         'account')

for name in NAMES:
    source = Image.open(ROOT / f'{name}.png').convert('RGBA')
    # Trace the half-coverage contour, not the faint antialiasing fringe.
    pixels = [(r, g, b, 255 if a >= 128 else 0)
              for r, g, b, a in source.getdata()]
    svg = vtracer.convert_pixels_to_svg(
        pixels, source.size, colormode='color', mode='spline',
        filter_speckle=3, color_precision=8, path_precision=2,
        corner_threshold=60, length_threshold=3.5, splice_threshold=45)
    width, height = source.size
    svg = svg.replace('<svg version="1.1"',
                      f'<svg viewBox="0 0 {width} {height}" version="1.1"')
    # Round path coordinates only; retain valid XML and SVG version numbers.
    def compact_path(match):
        return re.sub(r'-?\d+\.\d+',
                      lambda n: f'{float(n[0]):.2f}'.rstrip('0').rstrip('.'),
                      match[0])
    svg = re.sub(r'd="[^"]*"', compact_path, svg)
    (ROOT / 'icons' / f'{name}.svg').write_text(svg)

# Straight reference strokes use geometric paths rather than retaining the PNG
# antialiasing fringe as tiny bends in a scalable outline. View boxes and stroke
# widths are measured in the original cropped reference coordinates.
STROKES = {
    'back': (27, 44, 'M21 6 5 22 21 38', 3.5, '#000000'),
    'plus': (48, 46, 'M23 4V42M3 23H43', 2, '#000000'),
    'product-plus': (45, 43, 'M22 5V38M5 22H39', 4, '#000000'),
    'down': (37, 29, 'M3 7 18.5 22 33 7', 3.5, '#000000'),
    'chevron': (23, 41, 'M5 9 17 21 5 33', 3.5, '#C1C1D7'),
    'vendor-chevron': (25, 38, 'M5 5 18 19 5 32', 3.4, '#9A98AB'),
}
for name, (width, height, path, stroke, color) in STROKES.items():
    (ROOT / 'icons' / f'{name}.svg').write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'fill="none" stroke="{color}" stroke-width="{stroke}" '
        f'stroke-linecap="round" stroke-linejoin="round">'
        f'<path d="{path}"/></svg>\n')
