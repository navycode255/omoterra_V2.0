# Locations and owned assets

Finance → Locations & assets compares kitchen investment and trading over a selected period. Admins create locations, set daily chicken targets, register assets, record other capital and retire assets. Admins also enter opening stock costs. Staff allocate receipt/returned stock and record sales, operating expenses, returns and losses.

## Daily workflow

1. Allocate the actual stock delivered to the kitchen. Choose an existing delivery note/LPO receipt or enter already owned opening stock with its buying cost. Never enter receipt stock again as opening stock.
2. Record the quantity sold and selling price. Enter separate records for different prices or payment methods. Collected money becomes a normal buyer payment; unpaid money stays in the existing debts ledger.
3. Record labour and other expenses, paid or owed. Record unsold goods returned centrally or goods lost/spoiled with a reason.
4. Compare daily and period results across locations. Targets are planning quantities, not automatic transfers.

## Accounting

Location profit = sales − buying cost of goods sold − labour − other operating expenses − stock losses − depreciation. Purchase cost is not charged when stock is allocated. Internal transfers do not create a supplier debt, sale or expense. Receipt allocations leave the central pool and appear in location on-hand stock at the same cost. Business on-hand valuation includes both pools. Returns rejoin central receipt stock; returned opening stock retains its cost and can be reallocated through the returned-stock picker; losses are charged once in both location and business profit.

Sales are ordinary sales in the business ledger. Location expenses are ordinary expense debts, so they count once in total expenses whether paid or unpaid. Sale-linked expenses inherit their sale's location. Unassigned expenses remain shared business costs and are not silently distributed across kitchens. Marketplace sales are not attributed to kitchens in this version.

Investment is asset purchase cost plus other capital through the selected period end. Do not record an asset twice as both an asset and other investment. This is a capital register: it does not automatically create cash-book payments or supplier liabilities. Record actual capital payments separately in Finance, without classifying them as operating expenses.

Assets have purchase cost, residual value, useful life in months and a service start. Monthly straight-line depreciation is (cost − residual) ÷ useful months. Each service month runs from one service-date anniversary to the next; partial months are prorated by days. Differences between rounded cumulative values make reports additive across date splits. Depreciation stops at useful-life end or retirement, never drops book value below residual, and is included once as a non-cash expense in business profit and PDF reports. It never creates a cash payment.

Period return is selected-period profit after depreciation ÷ recorded investment. It is not annualised, lifetime payback or cash return. Asset book value is cost less accumulated depreciation. Profit belongs to the kitchen using the assets together; it is not arbitrarily attributed to individual stoves.

## History and corrections

Dates cannot be future dates, allocations cannot precede a receipt, sales cannot precede their allocation, and stock sold/returned/lost cannot exceed location on-hand. Fractional birds, animals, trays and pieces are refused. Mutations retry with idempotency keys. Admins can close/reopen locations and retire assets; history is retained.

Allocated-stock sales are corrected by reversing payments, cancelling with the goods outcome, and recording the replacement at the location. Cancellation with unrecovered goods records one location stock loss; accepted returns restore location on-hand. Existing general sales and expenses keep their original behaviour.

## Deployment and validation

Deploy backend and dashboard together, applying migration `037_locations_and_assets.sql` before requests use the new tables/columns. Tests cover location vs business profit, costs, depreciation, stock transfers from both receipt types, returns, overselling, lost stock, retry safety, permissions and migration/model parity. Production data is never used for tests.
