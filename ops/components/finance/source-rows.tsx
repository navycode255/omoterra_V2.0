import Link from 'next/link';
import { ListFooter } from './list-footer';
import styles from './finance-list.module.css';
import { day, type ReportRows } from '@/lib/finance';
import { tzs } from '@/lib/format';

// The rows behind part of a headline (GET /ops/finance/rows), for example
// delivered app orders still unpaid under "Owed to me": with the list above
// them they add up to the card. 10 a page; `href(page)` keeps the filters.
export function SourceRows({ title, note, data, empty, href, amountLabel = 'Amount' }: {
  title: string; note: string; data: ReportRows; empty: string; href: (page: number) => string; amountLabel?: string;
}) {
  return <section className={styles.panel} aria-label={title}>
    <h2>{title}</h2>
    <p className={styles.sourceNote}>{note} Total: <strong>{tzs(data.amount)}</strong></p>
    <div className={styles.tableWrap}>
      <table className={styles.table} data-phone-show="1 3">
        <thead><tr><th>Who</th><th>What</th><th>{amountLabel} (TZS)</th><th>Date</th></tr></thead>
        <tbody>{data.items.map((row) => <tr key={row.key}>
          <td data-label="Who">{row.href ? <Link className={styles.name} href={row.href}>{row.party || '—'}</Link> : row.party || '—'}</td>
          <td data-label="What">{row.description}</td>
          <td data-label={amountLabel} className={styles.money}>{tzs(row.amount)}</td>
          <td data-label="Date">{row.date ? day(row.date) : 'Date not recorded'}</td>
        </tr>)}</tbody>
      </table>
      {!data.items.length && <div className={styles.empty}><h2>{empty}</h2></div>}
    </div>
    <ListFooter data={data} label={title} href={href} perPage={false} />
  </section>;
}
