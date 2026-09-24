"""Add inventory history without replacing existing listings, orders or balances."""
from sqlalchemy import text, select
from .db import engine, Session
from . import models as m, inventory as inv
from .services import commerce_lock


def install_history_guards(engine):
    with engine.begin() as connection:
        connection.execute(text('''CREATE OR REPLACE FUNCTION omoterra_reject_history_edit()
        RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
          RAISE EXCEPTION 'Stock history and sale records are append-only';
        END; $$'''))
        for table in ['stock_movements', 'stock_sales', 'stock_sale_reversals']:
            connection.execute(text(f'DROP TRIGGER IF EXISTS immutable_history ON {table}'))
            connection.execute(text(f'CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON {table} FOR EACH ROW EXECUTE FUNCTION omoterra_reject_history_edit()'))


if __name__ == '__main__':
    m.StockMovement.__table__.create(engine, checkfirst=True)
    m.StockSale.__table__.create(engine, checkfirst=True)
    m.StockSaleReversal.__table__.create(engine, checkfirst=True)
    install_history_guards(engine)
    with Session.begin() as db:
        commerce_lock(db)
        for listing in db.scalars(select(m.Listing).with_for_update()):
            inv.ensure_history(db, listing)
    print('Stock history installed. Existing balances preserved.')
