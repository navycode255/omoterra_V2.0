import Link from 'next/link';
import { notFound } from 'next/navigation';
import { PrintButton } from '@/components/lpo/print-button';
import { ApiError, get } from '@/lib/api';
import { UNITS } from '@/lib/finance';
import type { LpoDetail, LpoLine } from '@/lib/lpo';
import { money, quantity } from '@/lib/format';
import { requireSession } from '@/lib/session';

export const metadata = { title: 'LPO · Omoterra' };

// Printed on the JOPEX letterhead. In print the letterhead is a fixed
// full-page image, so Chrome repeats it on every page, and the table's
// thead/tfoot spacers keep text clear of its header and footer on each page.
const CSS = `
.lpo-toolbar { max-width: 210mm; margin: 16px auto; display: flex; gap: 12px; align-items: center; justify-content: space-between; padding: 0 16px; }
.lpo-sheet { position: relative; width: 210mm; min-height: 297mm; margin: 0 auto 32px; background: #fff url('/images/lpo/letterhead.jpg') top center / 210mm 297mm no-repeat;
  box-shadow: 0 2px 16px rgba(0,0,0,.15); font-family: 'Times New Roman', Times, serif; color: #1b2733; font-size: 11pt; line-height: 1.35; }
.lpo-fixed { display: none; }
.lpo-body { width: 100%; border-collapse: collapse; }
.lpo-body > thead td { height: 48mm; } .lpo-body > tfoot td { height: 26mm; }
.lpo-body > tbody > tr > td { padding: 0 17mm; }
.lpo-title { text-align: center; color: #1f3b63; font-size: 21pt; font-weight: 700; margin: 0; }
.lpo-sub { text-align: center; color: #666; font-size: 10.5pt; margin: 2px 0 16px; }
.lpo-cols { display: grid; grid-template-columns: 1fr 1fr; gap: 9mm; }
.lpo-h { font-size: 12.5pt; font-weight: 700; margin: 14px 0 6px; padding-bottom: 4px; border-bottom: 1.6px solid #1f3b63; color: #1f3b63; }
.lpo-h.green { color: #1d6b45; border-color: #1d6b45; }
.lpo-kv { width: 100%; border-collapse: collapse; }
.lpo-kv td { padding: 4px 4px 4px 0; border-bottom: 1px solid #e6e6e6; vertical-align: top; }
.lpo-kv td:first-child { font-weight: 700; color: #1f3b63; width: 38%; }
.lpo-items { width: 100%; border-collapse: collapse; margin-top: 4px; }
.lpo-items th { background: #1f4e79; color: #fff; font-weight: 700; padding: 6px; border: 1px solid #c9d3de; text-align: left; font-size: 10.5pt; }
.lpo-items td { padding: 6px; border: 1px solid #c9d3de; vertical-align: middle; background: rgba(255,255,255,.85); }
.lpo-items .c { text-align: center; }
.lpo-list { margin: 4px 0 0; padding-left: 18px; } .lpo-list li { margin: 3px 0; }
.lpo-sign { display: grid; grid-template-columns: 1fr 1fr; gap: 9mm; margin-top: 16px; break-inside: avoid; }
.lpo-sign h4 { margin: 0; font-size: 11.5pt; color: #1f3b63; } .lpo-sign h4.green { color: #1d6b45; }
.lpo-sign .for { font-style: italic; color: #666; font-size: 10pt; margin-bottom: 8px; }
.lpo-sign p { margin: 7px 0; }
.lpo-blank { display: inline-block; min-width: 55mm; border-bottom: 1px solid #333; }
.lpo-sigline { position: relative; height: 16mm; display: flex; align-items: flex-end; }
.lpo-signature { height: 14mm; mix-blend-mode: multiply; position: absolute; left: 20mm; bottom: 1mm; }
.lpo-stamp { width: 40mm; mix-blend-mode: multiply; position: absolute; left: 36mm; bottom: -12mm; transform: rotate(-7deg); opacity: .92; }
.lpo-foot { text-align: center; font-style: italic; color: #777; font-size: 9pt; margin-top: 16mm; }
.lpo-mark { position: absolute; top: 120mm; left: 0; right: 0; text-align: center; font-size: 76pt; font-weight: 700;
  color: rgba(200, 40, 40, .13); transform: rotate(-24deg); pointer-events: none; letter-spacing: 8px; }
@page { size: A4; margin: 0; }
@media print {
  html, body { background: transparent !important; }
  .lpo-toolbar { display: none; }
  .lpo-sheet { box-shadow: none; margin: 0; background: none; min-height: 0; }
  .lpo-fixed { display: block; position: fixed; top: 0; left: 0; width: 210mm; height: 297mm; z-index: 0; }
  .lpo-body { position: relative; z-index: 1; }
  .lpo-mark { position: fixed; }
  * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .lpo-kv tr, .lpo-items tr, .lpo-list li { break-inside: avoid; }
}`;

const tzs = (value: string | number) => money(String(value));
const unitName = (value: string) => UNITS.find(([key]) => key === value)?.[1].replace(/s$/, '') ?? value;
const longDate = (value: string | null) => {
  if (!value) return '';
  const [y, m, d] = value.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d)).toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' });
};
// "27 to 30 September 2026", "28 September to 3 October 2026", or both dates in full.
function window_(start: string, end: string) {
  if (start === end) return longDate(start);
  const [first, last] = [longDate(start), longDate(end)];
  if (start.slice(0, 7) === end.slice(0, 7)) return `${first.split(' ')[0]} to ${last}`;
  if (start.slice(0, 4) === end.slice(0, 4)) return `${first.replace(/ \d{4}$/, '')} to ${last}`;
  return `${first} to ${last}`;
}

function priceBasis(line: LpoLine) {
  return `TZS ${tzs(line.unit_price)} per accepted ${unitName(line.unit).toLowerCase()}`;
}

export default async function LpoDocument({ params }: { params: Promise<{ id: string }> }) {
  await requireSession();
  const { id } = await params;
  let lpo: LpoDetail;
  try {
    lpo = await get<LpoDetail>(`/ops/lpos/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }
  const s = lpo.supplier_snapshot;
  const fixed = lpo.supply_basis === 'fixed';
  const total = lpo.lines.every((l) => l.quantity) ? lpo.lines.reduce((sum, l) => sum + Number(l.quantity) * Number(l.unit_price), 0) : null;
  const marked = lpo.stamped;
  const watermark = lpo.status === 'draft' ? 'DRAFT' : lpo.status === 'cancelled' ? 'CANCELLED' : null;
  const number = lpo.status === 'draft' ? 'Given when issued' : lpo.lpo_number;
  return (
    <>
      <style>{CSS}</style>
      <div className="lpo-toolbar">
        <Link href={`/lpos/${id}`}>← Back to the LPO</Link>
        <span className="meta">{watermark ? `This is a ${watermark.toLowerCase()} LPO. ` : ''}In the print dialog choose A4 and turn “Headers and footers” off.</span>
        <PrintButton />
      </div>
      <div className="lpo-sheet">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img className="lpo-fixed" src="/images/lpo/letterhead.jpg" alt="" />
        {watermark && <div className="lpo-mark">{watermark}</div>}
        <table className="lpo-body">
          <thead><tr><td /></tr></thead>
          <tfoot><tr><td /></tr></tfoot>
          <tbody><tr><td>
            <h1 className="lpo-title">LOCAL PURCHASE ORDER (LPO)</h1>
            <p className="lpo-sub">JOPEX Investment Ltd &nbsp;|&nbsp; Omoterra Business Unit</p>

            <div className="lpo-cols">
              <div>
                <div className="lpo-h">SUPPLIER DETAILS</div>
                <table className="lpo-kv"><tbody>
                  <tr><td>Supplier Name</td><td>{s.name}</td></tr>
                  <tr><td>Farm / Alias</td><td>{s.alias || '—'}</td></tr>
                  <tr><td>Primary Phone</td><td>{s.phone.replace(/^\+255(\d{3})(\d{3})(\d{3})$/, '+255 $1 $2 $3')}</td></tr>
                  <tr><td>District</td><td>{s.district || '—'}</td></tr>
                  <tr><td>Region</td><td>{s.region || '—'}</td></tr>
                  <tr><td>Farm Address</td><td>{s.farm_address || '—'}</td></tr>
                  <tr><td>Category</td><td>{[...new Set(lpo.lines.map((l) => l.item))].join(', ')}</td></tr>
                </tbody></table>
              </div>
              <div>
                <div className="lpo-h green">PURCHASE ORDER DETAILS</div>
                <table className="lpo-kv"><tbody>
                  <tr><td>LPO Number</td><td>{number}</td></tr>
                  <tr><td>LPO Date</td><td>{longDate(lpo.lpo_date)}</td></tr>
                  <tr><td>Buyer</td><td>JOPEX Investment Ltd (Omoterra)</td></tr>
                  <tr><td>Delivery Window</td><td>{window_(lpo.delivery_start, lpo.delivery_end)}</td></tr>
                  <tr><td>Currency</td><td>TZS</td></tr>
                  <tr><td>Payment Terms</td><td>{lpo.payment_terms_days === 0 ? 'On acceptance of each batch' : `Within ${lpo.payment_terms_days} day${lpo.payment_terms_days === 1 ? '' : 's'} of accepting each batch`}</td></tr>
                  <tr><td>Supply Basis</td><td>{fixed ? 'Fixed quantity, delivered in batches' : 'Batch by batch (call off basis)'}</td></tr>
                </tbody></table>
              </div>
            </div>

            <div className="lpo-h" style={{ marginTop: 20 }}>ITEM DETAILS</div>
            <table className="lpo-items">
              <thead><tr><th className="c">#</th><th>Item</th><th>Specification</th><th className="c">Unit</th><th className="c">Unit Price (TZS)</th><th className="c">Quantity</th><th className="c">Amount (TZS)</th></tr></thead>
              <tbody>
                {lpo.lines.map((line, i) => (
                  <tr key={line.id}>
                    <td className="c">{i + 1}</td>
                    <td>{line.item}</td>
                    <td>{line.specification}</td>
                    <td className="c">{unitName(line.unit)}</td>
                    <td className="c">{tzs(line.unit_price)}</td>
                    <td className="c">{line.quantity ? quantity(line.quantity) : 'As requested per batch'}</td>
                    <td className="c">{line.quantity ? tzs(String(Number(line.quantity) * Number(line.unit_price))) : 'Based on accepted quantity'}</td>
                  </tr>
                ))}
              </tbody>
            </table>

            <div className="lpo-h green" style={{ marginTop: 20 }}>ORDER SUMMARY</div>
            <table className="lpo-kv"><tbody>
              <tr><td>Price Basis</td><td>{lpo.lines.map(priceBasis).join('; ')}</td></tr>
              <tr><td>Quantity Commitment</td><td>{fixed ? `Fixed: ${lpo.lines.map((l) => `${quantity(l.quantity)} ${unitName(l.unit).toLowerCase()}s`).join(', ')}, delivered in batches` : 'Not fixed, confirmed per batch'}</td></tr>
              <tr><td>Total Order Value</td><td>{total !== null ? `TZS ${tzs(String(total))} maximum, payable on accepted quantities` : 'Determined by accepted batch quantities'}</td></tr>
            </tbody></table>

            <div className="lpo-h" style={{ marginTop: 20 }}>DELIVERY / COLLECTION NOTES</div>
            <ol className="lpo-list">{lpo.delivery_notes.map((n, i) => <li key={i}>{n}</li>)}</ol>

            <div className="lpo-h green" style={{ marginTop: 16 }}>TERMS AND CONDITIONS</div>
            <ol className="lpo-list">{lpo.terms.map((t, i) => <li key={i}>{t}</li>)}</ol>

            <div className="lpo-sign">
              <div>
                <h4>PREPARED / AUTHORIZED BY</h4>
                <div className="for">For JOPEX Investment Ltd (Omoterra)</div>
                <p>Name: {lpo.issuer_name || <span className="lpo-blank" />}</p>
                <p>Position: {lpo.issuer_position || <span className="lpo-blank" />}</p>
                <p>Date: {lpo.issued_at ? longDate(lpo.issued_at.slice(0, 10)) : <span className="lpo-blank" />}</p>
                <div className="lpo-sigline">
                  <span>Signature: <span className="lpo-blank" /></span>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  {marked && <img className="lpo-signature" src={`/lpo-doc/${id}/mark/signature`} alt="Signature" />}
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  {marked && <img className="lpo-stamp" src={`/lpo-doc/${id}/mark/stamp`} alt="Company stamp" />}
                </div>
              </div>
              <div>
                <h4 className="green">ACCEPTED BY SUPPLIER</h4>
                <div className="for">{s.name}</div>
                <p>Name: {lpo.supplier_accepted_name || <span className="lpo-blank" />}</p>
                <p>Position: {lpo.supplier_accepted_position || <span className="lpo-blank" />}</p>
                <p>Date: {lpo.supplier_accepted_at ? longDate(lpo.supplier_accepted_at) : <span className="lpo-blank" />}</p>
                <div className="lpo-sigline"><span>Signature: <span className="lpo-blank" /></span></div>
              </div>
            </div>
            <p className="lpo-foot">JOPEX Investment Ltd | Omoterra Business Unit | For business use only.</p>
          </td></tr></tbody>
        </table>
      </div>
    </>
  );
}
