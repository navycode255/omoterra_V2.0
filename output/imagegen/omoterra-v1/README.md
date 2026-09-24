# Omoterra V1 reference artwork

Generated using the built-in image_gen tool from the supplied screen reference.
Exact generation prompts are in [prompts.json](prompts.json).
Open [preview.html](preview.html) to review the set together.

These are reusable illustrations, not full-screen mockups or photographs of
actual supplier stock. Text, logos, icons, controls and progress bars belong in
the UI. The supplied product document was used as design context; this asset
pass does not implement its proposed demand and matching workflows.

## Page mapping

| Page | Artwork | Placement |
| --- | --- | --- |
| Supplier Home | `supplier-home-hero-v1.png` | Full-width header; hen on the right, heading on the left |
| Market Demand | `poultry-card-v1.png` | Reusable square thumbnail for poultry demand cards |
| Demand Detail / Supply This Demand | `demand-detail-hero-v1.png` | Portrait background; apply a dark UI scrim beneath white text |
| Admin Demand List | Existing Omoterra logo | The reference uses a table; no new raster artwork needed |
| Admin Matching | `poultry-card-v1.png` | Requirement and candidate-supply thumbnails |
| Supplier Reservations | `poultry-card-v1.png` | Reservation thumbnails |
| Supplier Payouts | UI gradient and existing icons | The reference's earnings card is a green gradient with vector icons |
| Welcome / brand background | `farm-landscape-v1.png` | Landscape under the existing logo and tagline |

## Asset locations

All four originals are in `mobile/assets/images/`, already covered by the
Flutter asset-directory declaration. Web copies are in
`ops/public/images/omoterra-v1/` and can be served as
`/images/omoterra-v1/<filename>`.

Existing assets are preserved. These versioned files are staged for the
reference-driven redesign; current screen widgets have not been changed.
Use real uploaded supplier photos in preference to illustrative thumbnails.

## Integration notes

- Flutter: `Image.asset('assets/images/supplier-home-hero-v1.png', fit: BoxFit.cover)`.
- With `BrandImage`, pass the extension explicitly: `BrandImage('supplier-home-hero-v1', extension: 'png', fallbackArt: 'broilers')`.
- Keep the card thumbnail centered when cropping; align the hero toward the right if its container is narrow.
- Add gradients as UI layers so contrast can be adjusted independently of the artwork.
- The landscape has a quiet central area for the existing Omoterra wordmark.
