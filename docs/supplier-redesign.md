# Supplier demand screen redesign

The mobile supplier experience follows the supplied home, market demand, and demand detail references, using the existing `supplier-home-hero-v1.png`, `poultry-card-v1.png`, and `demand-detail-hero-v1.png` assets.

- Home prioritizes Market Demand, followed by Add Stock, My Stock, Reservations (existing supplier orders), and Payouts. Stock statistics use actual inventory balances and stay separate by unit.
- Supplier navigation has Home, Demand, Stock, Orders, and Account. Buyer navigation remains unchanged.
- Market Demand supports category filtering, product/location search, one-time and repeating requirements, and matched quantities.
- Demand detail shows a supply offer form with quantity, readiness, expected average weight, and optional asking price. An offer is reviewed before reservation.
- Existing stock creation still submits to the existing API, with clearer growing-stock and expected-readiness wording.

## Integration status

Demand fixtures are available only through `LocalRepository` (`LOCAL_PREVIEW=true`). Preview writes deliberately fail; no offer or reservation is fabricated. The existing backend does **not** yet implement the following proposed endpoints. Live demand/offer functionality requires that backend work; this change does not migrate the data model or deploy services.

| Endpoint | Expected response / payload |
| --- | --- |
| `GET /supplier/demand` | Array of supplier-visible demand records |
| `GET /supplier/demand/:id` | One supplier-visible demand record |
| `POST /supplier/demand/:id/offers` | Quantity, ISO `ready_date`, numeric `expected_weight_kg`, optional numeric `asking_price`; existing idempotency header |

Demand records contain `id`, `category`, `unit`, `form`, `quantity`, `matched`, `weight` (display string), `region`, `needed_by` (ISO date), `repeating`, optional `schedule`, optional `buyer_type`, and supplier-safe `notes`. They must exclude buyer identity, contact details, and internal prices. Responses use the existing API envelope. The server must independently validate quantities, dates, eligibility, and idempotency, and must not reserve stock merely because an offer is submitted.

The broader product memo is context for this supplier redesign; the operations CRM, matching workspace, and reservation data model were not implemented by this UI change.
