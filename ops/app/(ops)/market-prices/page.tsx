import Link from 'next/link';
import { Notice, PageHeader, Status } from '@/components/ui';
import { ListFooter } from '@/components/finance/list-footer';
import { PriceLadder } from '@/components/market-prices/price-ladder';
import { WithdrawPrices } from '@/components/market-prices/withdraw-prices';
import styles from '@/components/market-prices/market-prices.module.css';
import { ApiError, get } from '@/lib/api';
import { category, date, dateTime } from '@/lib/format';
import { kg, shillings, PRICE_CATEGORIES, type OpsPrices, type PriceHistory, type PriceList } from '@/lib/market-prices';
import { param, type ListParams } from '@/lib/paging';

export const metadata = { title: 'Market Prices · Omoterra Operations' };

const IMAGES: Record<string, string> = { broilers: 'category_broilers.jpg', local_chicken: 'category_broilers.jpg', layers: 'category_eggs.jpg',
  eggs: 'category_eggs.jpg', goats: 'category_goats.jpg', cattle: 'category_cow.jpg', chicken_meat: 'category_broilers.jpg', beef: 'category_cow.jpg', goat_meat: 'category_goats.jpg' };
const TONE = { current: 'positive', scheduled: 'warning', superseded: 'neutral', withdrawn: 'error' } as const;
const STATUS = { current: 'Live', scheduled: 'Scheduled', superseded: 'Replaced', withdrawn: 'Withdrawn' };

function range(list: PriceList) {
  const prices = list.bands.map((band) => Number(band.price_per_unit));
  const low = Math.min(...prices), high = Math.max(...prices);
  return low === high ? shillings(low) : `${shillings(low)} – ${shillings(high).replace('TZS ', '')}`;
}

function Gaps({ list }: { list: PriceList }) {
  if (!list.gaps.length) return null;
  return <div className={styles.warning}>No price for {list.gaps.map((gap) => `${Number(gap.from_kg).toFixed(2)} – ${kg(gap.to_kg)}`).join(' or ')}.</div>;
}

export default async function MarketPrices({ searchParams }: { searchParams: Promise<ListParams> }) {
  const params = await searchParams;
  const filter = PRICE_CATEGORIES.includes(param(params, 'category') as never) ? param(params, 'category') : '';
  const page = Math.max(1, Number(param(params, 'page')) || 1);
  const pageSize = Math.min(100, Math.max(1, Number(param(params, 'page_size')) || 10));
  let prices: OpsPrices, history: PriceHistory;
  try {
    [prices, history] = await Promise.all([
      get<OpsPrices>('/ops/market-prices'),
      get<PriceHistory>(`/ops/market-prices/history?${new URLSearchParams({ category: filter, page: String(page), page_size: String(pageSize) })}`),
    ]);
  } catch (error) {
    return <><div className="topbar"><PageHeader title="Market Prices"/></div><div className="workspace"><Notice tone="error">{error instanceof ApiError ? error.message : 'Market prices could not be loaded.'}</Notice></div></>;
  }
  const priced = prices.categories.filter((row) => row.current || row.upcoming.length);
  const unpriced = prices.categories.filter((row) => !row.current && !row.upcoming.length);
  const published = param(params, 'published');
  const historyHref = (n: number, key = filter) => `/market-prices?${new URLSearchParams({ ...(key && { category: key }), page: String(n), ...(pageSize !== 10 && { page_size: String(pageSize) }) })}#history`;

  return <>
    <div className="topbar between">
      <PageHeader title="Market Prices" info="The price Omoterra pays per bird, animal, kg or tray, by weight. Suppliers see the live prices on their dashboard."/>
      {prices.can_publish && <Link className="button" href="/market-prices/new">Update prices</Link>}
    </div>
    <div className="workspace">
      {published && <Notice>New {category(published).toLowerCase()} prices published. Suppliers of {category(published).toLowerCase()} have been notified.</Notice>}
      {!prices.can_publish && <Notice>Only admins can publish or withdraw prices.</Notice>}

      {priced.length ? <div className={styles.boards}>
        {priced.map((board) => {
          const live = board.current;
          return <section key={board.category} className={styles.board} aria-label={`${category(board.category)} prices`}>
            <div className={styles.boardHead}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={`/images/marketing/${IMAGES[board.category]}`} alt=""/>
              <div><strong>{category(board.category)}</strong><small>{live ? `${range(live)} per ${board.unit_type} · since ${date(live.effective_from)}` : 'No live price yet'}</small></div>
              {live && <Status tone="positive">Live</Status>}
            </div>
            {live && <><PriceLadder bands={live.bands} unit={board.unit_type}/><Gaps list={live}/></>}
            {board.upcoming.map((next) => <div key={next.id} className={styles.upcoming}>
              <div className={styles.upcomingHead}><span>Changes on <b>{date(next.effective_from)}</b></span><Status tone="warning">Scheduled</Status></div>
              <PriceLadder bands={next.bands} unit={board.unit_type} compact/>
              <Gaps list={next}/>
              {prices.can_publish && <div className={styles.boardActions}><WithdrawPrices id={next.id} scheduled/></div>}
            </div>)}
            {live && <p className={styles.meta}>Published {dateTime(live.published_at)}{live.published_by ? ` by ${live.published_by}` : ''}{live.note ? ` · ${live.note}` : ''}</p>}
            {prices.can_publish && <div className={styles.boardActions}>
              {live && <WithdrawPrices id={live.id} scheduled={false}/>}
              <Link className="button" data-variant="secondary" href={`/market-prices/new?category=${board.category}`}>Update {category(board.category).toLowerCase()}</Link>
            </div>}
          </section>;
        })}
      </div> : <div className={`card ${styles.empty}`}><b>No market prices yet</b>{prices.can_publish ? 'Publish a price list so suppliers know what Omoterra pays for each weight.' : 'An admin has not published any prices yet.'}{prices.can_publish && <p><Link className="button" href="/market-prices/new">Set the first prices</Link></p>}</div>}

      {priced.length > 0 && unpriced.length > 0 && <div className={styles.missing}>
        <span>No prices yet:</span>
        {unpriced.map((row) => prices.can_publish
          ? <Link key={row.category} className={styles.chip} href={`/market-prices/new?category=${row.category}`}>+ {category(row.category)}</Link>
          : <span key={row.category} className={styles.chip}>{category(row.category)}</span>)}
      </div>}

      <section className={`card ${styles.history}`} id="history">
        <div className="between">
          <h2 className="card-title">Price history</h2>
          <nav className={styles.missing} style={{ border: 0, padding: 0, background: 'none' }} aria-label="Filter history">
            <Link className={styles.chip} href={historyHref(1, '')} aria-current={!filter || undefined} style={!filter ? { borderColor: 'var(--forest)', color: 'var(--forest)' } : undefined}>All</Link>
            {priced.map((row) => <Link key={row.category} className={styles.chip} href={historyHref(1, row.category)} aria-current={filter === row.category || undefined}
              style={filter === row.category ? { borderColor: 'var(--forest)', color: 'var(--forest)' } : undefined}>{category(row.category)}</Link>)}
          </nav>
        </div>
        {history.items.length ? <div className="table-wrap"><table data-phone-show="1 3">
          <thead><tr><th>Applies from</th><th>Product</th><th>Prices</th><th>Bands</th><th>Status</th><th>Published</th></tr></thead>
          <tbody>{history.items.map((list) => <tr key={list.id}>
            <td>{date(list.effective_from)}</td>
            <td>{category(list.category)}</td>
            <td>{range(list)}<small>per {list.unit_type}</small></td>
            <td>{list.bands.length}</td>
            <td><Status tone={TONE[list.status]}>{STATUS[list.status]}</Status>{list.status === 'withdrawn' && <small>{list.withdraw_reason}{list.withdrawn_by ? ` · ${list.withdrawn_by}` : ''}</small>}</td>
            <td>{dateTime(list.published_at)}<small>{list.published_by}{list.note ? ` · ${list.note}` : ''}</small></td>
          </tr>)}</tbody>
        </table></div> : <p className="meta">No price lists published yet.</p>}
        {history.total > 0 && <ListFooter data={history} href={(n) => historyHref(n)} label="Price history"/>}
      </section>
    </div>
  </>;
}
