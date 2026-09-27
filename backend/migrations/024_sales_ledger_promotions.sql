-- Sales staff record directly, one ledger of who owes whom, and promotion
-- messages to buyers and suppliers.
--
-- A sale is a money record only: it never touches listings or batches. Every
-- sale opens a receivable (the buyer owes Omoterra) and, for lines bought
-- from a supplier, a payable (Omoterra owes that supplier). Other debts
-- (loans, feed on credit...) are manual ledger rows of the same kind, and so
-- are operating expenses, so one balance covers everything and profit is
-- sales less stock cost less expenses. Payments are never deleted: a mistake is
-- reversed, with a reason, and the balance moves back.
BEGIN;
CREATE TABLE IF NOT EXISTS sales (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    sale_number VARCHAR(24) NOT NULL UNIQUE,
    sold_on DATE NOT NULL,
    -- Every sale has a buyer CRM record (created for new or app buyers), so
    -- the buyer is kept for later orders and promotions.
    buyer_profile_id VARCHAR(36) NOT NULL REFERENCES buyer_profiles(id),
    buyer_user_id VARCHAR(36) REFERENCES users(id),
    buyer_name TEXT NOT NULL,
    buyer_phone VARCHAR(20) NOT NULL DEFAULT '',
    total_amount NUMERIC(14, 2) NOT NULL CHECK (total_amount > 0),
    cost_amount NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (cost_amount >= 0),
    notes TEXT NOT NULL DEFAULT '',
    status VARCHAR(16) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled')),
    created_by VARCHAR(36) REFERENCES operators(id),
    cancelled_at TIMESTAMPTZ,
    cancelled_by VARCHAR(36) REFERENCES operators(id),
    cancel_reason TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS ix_sales_buyer_profile ON sales(buyer_profile_id);
CREATE INDEX IF NOT EXISTS ix_sales_sold_on ON sales(sold_on);

CREATE TABLE IF NOT EXISTS sale_items (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    sale_id VARCHAR(36) NOT NULL REFERENCES sales(id),
    position INTEGER NOT NULL,
    category VARCHAR(32) NOT NULL DEFAULT '',
    description TEXT NOT NULL,
    unit VARCHAR(16) NOT NULL,
    quantity NUMERIC(14, 3) NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(14, 2) NOT NULL CHECK (unit_price > 0),
    subtotal NUMERIC(14, 2) NOT NULL,
    -- Where the stock came from, when Omoterra owes someone for it: a
    -- registered supplier, or a named one not (yet) in the system.
    supplier_id VARCHAR(36) REFERENCES users(id),
    supplier_name TEXT NOT NULL DEFAULT '',
    unit_cost NUMERIC(14, 2) CHECK (unit_cost > 0),
    cost_total NUMERIC(14, 2),
    CONSTRAINT sale_item_cost_has_supplier CHECK (
        (unit_cost IS NULL AND supplier_id IS NULL AND supplier_name = '')
        OR (unit_cost IS NOT NULL AND (supplier_id IS NOT NULL OR supplier_name <> '')))
);
CREATE INDEX IF NOT EXISTS ix_sale_items_sale ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS ix_sale_items_supplier ON sale_items(supplier_id);

CREATE TABLE IF NOT EXISTS ledger_debts (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    -- receivable: someone owes Omoterra. payable: Omoterra owes someone.
    direction VARCHAR(16) NOT NULL CHECK (direction IN ('receivable', 'payable')),
    party_kind VARCHAR(16) NOT NULL CHECK (party_kind IN ('buyer', 'supplier', 'other')),
    buyer_profile_id VARCHAR(36) REFERENCES buyer_profiles(id),
    supplier_id VARCHAR(36) REFERENCES users(id),
    party_name TEXT NOT NULL,
    party_phone VARCHAR(20) NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    -- Kept equal to the sum of this debt's unreversed payments, under a row
    -- lock, so the database itself refuses an overpayment.
    paid_amount NUMERIC(14, 2) NOT NULL DEFAULT 0,
    incurred_on DATE NOT NULL,
    due_on DATE,
    -- sale / sale_cost: opened by a sale. manual: any other debt. expense: an
    -- operating cost (labour, transport...), paid now or owed; it may name
    -- the sale it was spent on.
    source VARCHAR(16) NOT NULL CHECK (source IN ('sale', 'sale_cost', 'manual', 'expense')),
    expense_category VARCHAR(24) CHECK (expense_category IN ('labour', 'transport', 'fuel', 'feed',
        'medicine_vet', 'packaging', 'processing', 'market_fees', 'rent', 'utilities', 'airtime_data',
        'equipment', 'repairs', 'other')),
    sale_id VARCHAR(36) REFERENCES sales(id),
    status VARCHAR(16) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'settled', 'cancelled')),
    created_by VARCHAR(36) REFERENCES operators(id),
    cancelled_at TIMESTAMPTZ,
    cancelled_by VARCHAR(36) REFERENCES operators(id),
    cancel_reason TEXT NOT NULL DEFAULT '',
    CONSTRAINT ledger_paid_within_amount CHECK (paid_amount >= 0 AND paid_amount <= amount),
    CONSTRAINT ledger_sale_source CHECK (source = 'expense' OR (source = 'manual') = (sale_id IS NULL)),
    CONSTRAINT ledger_expense_category CHECK ((source = 'expense') = (expense_category IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS ix_ledger_debts_open ON ledger_debts(direction, status);
CREATE INDEX IF NOT EXISTS ix_ledger_debts_sale ON ledger_debts(sale_id);
CREATE INDEX IF NOT EXISTS ix_ledger_debts_buyer ON ledger_debts(buyer_profile_id);
CREATE INDEX IF NOT EXISTS ix_ledger_debts_supplier ON ledger_debts(supplier_id);
CREATE INDEX IF NOT EXISTS ix_ledger_debts_expenses ON ledger_debts(incurred_on) WHERE source = 'expense';

CREATE TABLE IF NOT EXISTS ledger_payments (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    debt_id VARCHAR(36) NOT NULL REFERENCES ledger_debts(id),
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    paid_on DATE NOT NULL,
    method VARCHAR(24) NOT NULL CHECK (method IN ('cash', 'mpesa', 'airtel_money', 'mixx_by_yas', 'halopesa', 'bank_transfer', 'cheque', 'other')),
    reference TEXT NOT NULL DEFAULT '',
    note TEXT NOT NULL DEFAULT '',
    recorded_by VARCHAR(36) REFERENCES operators(id),
    reversed_at TIMESTAMPTZ,
    reversed_by VARCHAR(36) REFERENCES operators(id),
    reverse_reason TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS ix_ledger_payments_debt ON ledger_payments(debt_id);
CREATE INDEX IF NOT EXISTS ix_ledger_payments_paid_on ON ledger_payments(paid_on);
-- The same transaction reference cannot be recorded twice against one debt.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ledger_payment_reference ON ledger_payments(debt_id, method, reference)
    WHERE reference <> '' AND reversed_at IS NULL;

CREATE TABLE IF NOT EXISTS promotions (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    audience VARCHAR(16) NOT NULL CHECK (audience IN ('buyers', 'suppliers', 'everyone')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    send_sms BOOLEAN NOT NULL,
    send_in_app BOOLEAN NOT NULL,
    recipient_count INTEGER NOT NULL DEFAULT 0,
    in_app_count INTEGER NOT NULL DEFAULT 0,
    created_by VARCHAR(36) REFERENCES operators(id),
    CONSTRAINT promotion_has_channel CHECK (send_sms OR send_in_app)
);

CREATE TABLE IF NOT EXISTS promotion_recipients (
    id VARCHAR(36) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    promotion_id VARCHAR(36) NOT NULL REFERENCES promotions(id),
    phone VARCHAR(20) NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    user_id VARCHAR(36) REFERENCES users(id),
    buyer_profile_id VARCHAR(36) REFERENCES buyer_profiles(id),
    sms_status VARCHAR(16) NOT NULL CHECK (sms_status IN ('queued', 'sent', 'failed', 'skipped')),
    sms_error TEXT NOT NULL DEFAULT '',
    sms_attempts INTEGER NOT NULL DEFAULT 0,
    sent_at TIMESTAMPTZ,
    CONSTRAINT uq_promotion_phone UNIQUE (promotion_id, phone)
);
CREATE INDEX IF NOT EXISTS ix_promotion_recipients_queued ON promotion_recipients(sms_status) WHERE sms_status = 'queued';

-- Numbers that asked not to receive promotions.
CREATE TABLE IF NOT EXISTS promotion_opt_outs (
    phone VARCHAR(20) PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    note TEXT NOT NULL DEFAULT ''
);
COMMIT;
