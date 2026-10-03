import { heaviestFirst, kg, priceChange, shillings, weightRange, type PriceBand } from '@/lib/market-prices';
import styles from './market-prices.module.css';

// One price list read as a ladder: heaviest and best-paid band on top, and
// any weights without a price shown where they fall between the bands.
export function PriceLadder({ bands, unit, gapNote = 'No price set', compact = false }: {
  bands: PriceBand[]; unit: string; gapNote?: string; compact?: boolean;
}) {
  const ordered = heaviestFirst(bands);
  const top = Math.max(...bands.map((band) => Number(band.price_per_unit)));
  return <ol className={styles.ladder} data-compact={compact || undefined}>
    {ordered.map((band, index) => {
      const lighter = ordered[index + 1];
      const gap = lighter?.max_weight_kg && band.min_weight_kg && Number(lighter.max_weight_kg) < Number(band.min_weight_kg);
      const change = priceChange(band);
      return <li key={`${band.min_weight_kg}-${band.max_weight_kg}`} className={styles.rungWrap}>
        <div className={styles.rung} style={{ '--level': `${Math.max(.25, Number(band.price_per_unit) / top)}` } as React.CSSProperties}>
          <span className={styles.weight}>
            <b>{weightRange(band)}</b>
            {band.label && <small>{band.label}</small>}
          </span>
          <span className={styles.price}>
            <b>{shillings(band.price_per_unit)}</b>
            <small>per {unit}</small>
            {change !== null && <em data-direction={change > 0 ? 'up' : 'down'} title={`Was ${shillings(band.previous_price!)}`}>
              {change > 0 ? '▲' : '▼'} {shillings(Math.abs(change)).replace('TZS ', '')}
            </em>}
          </span>
        </div>
        {gap && <div className={styles.gap}><span>{kg(lighter.max_weight_kg!).replace(' kg', '')} – {kg(band.min_weight_kg!)}</span><small>{gapNote}</small></div>}
      </li>;
    })}
  </ol>;
}
