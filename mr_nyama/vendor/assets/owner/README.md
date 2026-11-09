# Approved owner artwork

The supplied reference PNGs are retained in
`docs/mr_nyama/design/screenshots/owner-approved-2026-10-22/` at repo root.

`icons/*.svg`: 14 scalable reference-derived interface glyphs, plus
`verify.svg` (Uthibitisho), drawn by hand to the same line weight because the
references have no verification glyph. `shop.svg`, `menu-list.svg` and `stock-box.svg` (Station page) are hand-drawn the same way. The trace tool does not overwrite them. `brand.png` is the
supplied brand mark. Other PNGs retain the original extracted glyphs and nine
product photographs. The brand and photography are not regenerated or redrawn.

Regenerate the icon silhouettes from vendor/: `python3 tool/trace_owner_icons.py`.
Build-time requirements: Pillow and vtracer 0.6.15. No runtime dependency is added.
The SVGs preserve source aspect ratios; OwnerGlyph keeps the approved layout
sizes and supports navigation-state tinting and accessible button labels.
