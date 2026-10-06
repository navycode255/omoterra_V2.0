import Link from 'next/link';
import { Icons } from '@/components/icons';
import { InfoTip } from '@/components/info-tip';
import { tzs } from '@/lib/format';
import type { FinanceSummary } from '@/lib/finance';
import styles from './business-position.module.css';

export function signedAmount(value: string, positive = false) {
  const number = Number(value);
  return `${number < 0 ? '− ' : positive && number > 0 ? '+ ' : ''}${tzs(String(Math.abs(number)))}`;
}

export function BusinessPosition({ data }: { data: FinanceSummary | null }) {
  const profit = data?.profit_selected;
  const result = profit ? Number(profit.net_profit) : null;
  const balance = data ? Number(data.all_time.net) : null;
  return <section className={styles.panel} aria-labelledby="business-position-title">
    <header className={styles.heading}><Icons.chart size={22}/><h2 id="business-position-title">Business position</h2><InfoTip label="About business position">Recorded cash position is all recorded money in minus money out since records began, across payment methods. It includes recorded direct-sale and app money movements, but has no opening account balance or account count, so it is not a verified bank or cash balance. Operating result is profit after recorded costs for the selected dates. Debts are current outstanding balances and are not deducted from recorded cash position.{profit?.provisional ? ` ${profit.provisional_label || 'Buying costs are incomplete; the result is provisional.'}` : ''}</InfoTip></header>
    {data ? <>
      <div className={styles.main}>
        <div className={styles.balance}><span>Recorded cash position</span><Link href="/finance/cash-book?dates=all" className={styles.amount} data-tone={balance! < 0 ? 'negative' : 'neutral'}>{signedAmount(data.all_time.net)}</Link><small>Unverified</small></div>
        <div className={styles.result}><span>Operating result</span><Link href={`/finance/profit?start=${data.selected.start}&end=${data.selected.end}`} className={styles.amount} data-tone={result! < 0 ? 'negative' : result! > 0 ? 'positive' : 'neutral'}>{signedAmount(profit!.net_profit, true)}</Link><small data-tone={profit!.provisional ? 'provisional' : result! < 0 ? 'negative' : result! > 0 ? 'positive' : 'neutral'}>{profit!.provisional ? 'Provisional' : result! < 0 ? 'Loss' : result! > 0 ? 'Profit' : 'Break-even'}</small></div>
      </div>
      <div className={styles.debts}><Link href="/finance/debts?status=owed_to_me"><Icons.wallet size={21}/><div><span>Owed to you</span><strong>{signedAmount(data.owed_to_me.total)}</strong></div></Link><Link href="/finance/debts?status=i_owe"><Icons.card size={21}/><div><span>You owe</span><strong>{signedAmount(data.i_owe.total)}</strong></div></Link></div>
    </> : <p className={styles.unavailable}>Financial figures unavailable. <Link href="/finance">Open Finance</Link></p>}
  </section>;
}
