# Stock and sales testing

Open http://localhost:8080 and sign in with **+255700000001**. The local development verification code appears on the verification screen. This explicitly named test account supports both roles; switch roles in Account. The seeded sample records are development scenarios, not actual commerce.

## Supplier workflow

Open Stock → Broilers. Four separate actions preserve the reason for each change:

- **Record a sale**: goods sold outside Omoterra. Deducts available stock, increases sold quantity, and saves the date, optional price and note. Reserved goods cannot be sold this way.
- **Correct stock count**: fixes a recording mistake. Enter stock physically on hand, including reserved goods. Sold quantity stays unchanged. A reason is required.
- **Add to this stock**: records newly received stock matching the existing listing specifications, with a receipt/batch note. Use Add Stock for a different batch/product.
- **Stock history**: opening balances, receipts, corrections, reservations, releases and sales, with running available/reserved/sold balances.

Omoterra orders create their sales automatically at delivery using accepted quantity. Retrying delivery cannot deduct twice. External sales never create an Omoterra settlement. Both sources are separately labelled/filterable in Sales records. A wrongly recorded external sale can be reversed from its details with a reason; stock returns, while both original sale and reversal remain recorded.

Stock history and sale records are append-only in PostgreSQL. Existing listings receive an explicit opening balance; earlier activity is not fabricated. Units remain separate in summaries (birds, animals, kg).

## Screens to exercise

- Welcome → phone → verification → roles → buyer type → profile (use a new phone for onboarding).
- Buyer home → Explore/filter → listing → quantity/reservation → checkout/address → confirmation → tracking/cancellation.
- Request supply → submitted → request progress; business options → details → setup-plan request.
- Supplier home → category → stock details → pricing/location → photos → preview/submit → pending review.
- Supplier stock → sale/correction/receipt/history; Sales records → detail/reversal; collection detail; payouts/detail.
- Account → role switching, profile, addresses, help and sign out.

The test account includes six buyer orders in different states, four sourcing requests, seven own stock categories, two supplier settlements, automatic and external sales, and correction/receipt history. New listings still require operator approval. The existing Ops dashboard and this preview share the same local API/database.

## Restart the local preview

From `backend`, after building the web target:

```bash
OMOTERRA_DEV_API_UPSTREAM=http://127.0.0.1:8010 .venv/bin/uvicorn app.dev:app --host 127.0.0.1 --port 8080
```

For an existing database, set `OMOTERRA_DATABASE_URL` then run `.venv/bin/python -m app.migrate_inventory`. The optional development-only `.venv/bin/python -m app.seed_testing` creates labelled scenarios once, preserving existing accounts and records. The preview proxy preserves existing uploaded media access.

Real SMS and mobile-money payments remain unconfigured. Local authentication displays its development code; checkout currently supports Pay on Delivery. App copy is English; full Swahili translation remains pending.
