import { PriceLadder } from '@/components/market-prices/price-ladder';
import type { PriceBoard } from '@/lib/market-prices';
import { CATEGORY, categoryImage, date, label } from './supplier-format';
import { Icon } from './icons';

// Live market prices on the supplier dashboard. The supplier's own products
// come first; other priced products follow so they can plan new batches.
export function MarketPricesCard({ boards, categories }: { boards: PriceBoard[]; categories: string[] }) {
  if (!boards.length) return null;
  const mine = boards.filter((board) => categories.includes(board.category));
  const shown = [...mine, ...boards.filter((board) => !categories.includes(board.category))];
  return <section className="portal-card portal-prices" aria-labelledby="market-prices-title">
    <h2 id="market-prices-title"><Icon name="coins" />Market prices today</h2>
    <p className="portal-prices-lead">What Omoterra pays for each weight. Heavier, well-grown stock earns the top price.</p>
    <div className="portal-prices-grid">
      {shown.map((board) => {
        const unit = CATEGORY[board.category]?.[1] ?? board.unit_type;
        const next = board.upcoming[0];
        return <article key={board.category} className="portal-price-board">
          <header>
            <span className="portal-batch-photo" style={{ backgroundImage: `url(${categoryImage(board.category)})` }} />
            <span><b>{label(board.category)}</b><small>{board.current ? `Updated ${date.format(new Date(board.current.effective_from))}` : 'Prices coming soon'}</small></span>
            {categories.includes(board.category) && <span className="portal-badge is-approved">You supply</span>}
          </header>
          {board.current && <PriceLadder bands={board.current.bands} unit={unit} gapNote="Ask Omoterra" compact />}
          {next && <div className="portal-price-next">
            <p><Icon name="calendar" />New prices from <b>{date.format(new Date(next.effective_from))}</b></p>
            <PriceLadder bands={next.bands} unit={unit} gapNote="Ask Omoterra" compact />
          </div>}
        </article>;
      })}
    </div>
    <p className="portal-note">Prices can change with the market. The price on your order or invoice is the one you are paid.</p>
  </section>;
}
