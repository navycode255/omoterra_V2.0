# Photography

Drop files here using these exact names and they appear in the app. Until a
file exists, the screen falls back to the built-in vector artwork, so nothing
breaks while photography is outstanding.

| File | Used on | Suggested size | Status |
| --- | --- | --- | --- |
| `splash.jpg` | Splash background | 1080 x 1920 | ✅ |
| `welcome.jpg` | Welcome hero | 1080 x 1100 | ✅ |
| `logo.png` | Wordmark | — | ✅ |
| `category_broilers.jpg` | Broilers tiles, listing fallback | 800 x 800 | ✅ |
| `category_local_chicken.jpg` | Local chicken tiles, listing fallback | 800 x 800 | ✅ |
| `category_goats.jpg` | Goats tiles, listing fallback; also goat_meat fallback | 800 x 800 | ✅ |
| `category_cow.jpg` | Beef listing fallback (cattle has no live-sale category in V1) | 800 x 800 | ✅ |
| `category_eggs.jpg` | Eggs tiles, listing fallback | 800 x 800 | ✅ |
| `category_chicken_meat.jpg` | chicken_meat fallback — currently borrows category_broilers.jpg | 800 x 800 | missing |
| `category_goat_meat.jpg` | goat_meat fallback — currently borrows category_goats.jpg | 800 x 800 | missing |
| `category_other.jpg` | Uncategorised fallback | 800 x 800 | missing |
| `dashboard_banner.jpg` | Buyer Home "Buy Supply" hero card | 1600 x 900 | ✅ (still .png, needs converting) |
| `business_chicken_shop.jpg` | Start a Business | 1080 x 720 |
| `business_butchery.jpg` | " | 1080 x 720 |
| `business_fish_shop.jpg` | " | 1080 x 720 |
| `business_meat_delivery.jpg` | " | 1080 x 720 |
| `business_egg_reseller.jpg` | " | 1080 x 720 |
| `business_local_chicken_business.jpg` | " | 1080 x 720 |
| `business_goat_meat_business.jpg` | " | 1080 x 720 |
| `business_restaurant_grill.jpg` | " | 1080 x 720 |

Keep the `.jpg` extension even for PNG source files, or update the name in
`lib/shared/widgets/brand_image.dart`.

Prefer real photography of Tanzanian farms and livestock. Avoid images where a
supplier's face, signage, vehicle plate or location is identifiable, since
listing imagery is buyer-facing and suppliers must stay anonymous.

Keep each file under ~300 KB so the app stays small.
