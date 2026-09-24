import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Card, PageHeader } from '@/components/ui';
import { createRequirement } from '@/lib/actions';
import { titleCase } from '@/lib/format';

export const metadata = { title: 'Record buyer demand · Omoterra Operations' };
const products = [
  ['broilers','Broilers'], ['local_chicken','Local chicken'], ['goats','Goats'], ['cattle','Cattle'],
  ['chicken_meat','Chicken meat'], ['beef','Beef'], ['goat_meat','Goat meat'], ['eggs','Eggs'],
];

export default function NewDemand() {
  return <>
    <div className="topbar"><PageHeader title="Record buyer demand" subtitle="Create the same requirement record used by the buyer app, including for an offline business." /></div>
    <div className="workspace"><Card title="Requirement details">
      <ActionForm action={createRequirement} label="Save requirement">
        <div className="grid-2">
          <div className="field"><label htmlFor="business_name">Business name (optional)</label><input className="input" id="business_name" name="business_name" placeholder="Offline buyer or app account" /></div>
          <div className="field"><label htmlFor="buyer_type">Buyer type</label><select className="input" id="buyer_type" name="buyer_type" defaultValue="restaurant"><option value="restaurant">Restaurant</option><option value="butchery">Butchery</option><option value="hotel">Hotel</option><option value="retailer">Retailer</option><option value="caterer">Caterer</option><option value="personal">Personal</option><option value="other">Other</option></select></div>
          <div className="field"><label htmlFor="contact_person">Contact person</label><input className="input" id="contact_person" name="contact_person" /></div>
          <div className="field"><label htmlFor="phone">Phone</label><input className="input" id="phone" name="phone" inputMode="tel" /></div>
          <div className="field"><label htmlFor="category">Product</label><select className="input" id="category" name="category" required>{products.map(([id,label]) => <option key={id} value={id}>{label}</option>)}</select></div>
          <div className="field"><label htmlFor="product_subtype">Subtype / breed</label><input className="input" id="product_subtype" name="product_subtype" /></div>
          <div className="field"><label htmlFor="quantity">Quantity</label><input className="input" id="quantity" name="quantity" inputMode="decimal" required /></div>
          <div className="field"><label htmlFor="needed_by_date">Needed by</label><input className="input" id="needed_by_date" name="needed_by_date" type="date" required /></div>
          <div className="field"><label htmlFor="minimum_weight_kg">Minimum weight (kg)</label><input className="input" id="minimum_weight_kg" name="minimum_weight_kg" inputMode="decimal" /></div>
          <div className="field"><label htmlFor="maximum_weight_kg">Maximum weight (kg)</label><input className="input" id="maximum_weight_kg" name="maximum_weight_kg" inputMode="decimal" /></div>
          <div className="field"><label htmlFor="form">Form</label><select className="input" id="form" name="form" defaultValue="live"><option value="live">Live</option><option value="dressed">Dressed</option><option value="chilled">Chilled</option><option value="frozen">Frozen</option></select></div>
          <div className="field"><label htmlFor="requirement_type">Requirement type</label><select className="input" id="requirement_type" name="requirement_type" defaultValue="one_time"><option value="one_time">One time</option><option value="recurring">Recurring</option></select></div>
          <div className="field"><label htmlFor="recurrence_frequency">Frequency</label><select className="input" id="recurrence_frequency" name="recurrence_frequency" defaultValue=""><option value="">One time</option><option value="weekly">Weekly</option><option value="monthly">Monthly</option></select></div>
          <div className="field"><label htmlFor="delivery_region">Delivery region</label><input className="input" id="delivery_region" name="delivery_region" required /></div>
          <div className="field"><label htmlFor="delivery_area">Delivery area</label><input className="input" id="delivery_area" name="delivery_area" required /></div>
          <div className="field"><label htmlFor="delivery_notes">Delivery instructions (private)</label><input className="input" id="delivery_notes" name="delivery_notes" /></div>
          <div className="field"><label htmlFor="weight_or_size_requirement">Weight / size notes</label><input className="input" id="weight_or_size_requirement" name="weight_or_size_requirement" /></div>
        </div>
        <fieldset className="field"><legend>Preferred weekdays for recurring demand</legend><div className="row" style={{ flexWrap: 'wrap' }}>{['monday','tuesday','wednesday','thursday','friday','saturday','sunday'].map((day) => <label key={day} className="row"><input type="checkbox" name="preferred_weekdays" value={day} />{titleCase(day)}</label>)}</div></fieldset>
        <div className="field"><label htmlFor="notes">Buyer notes</label><textarea className="input" id="notes" name="notes" /></div>
        <div className="field"><label htmlFor="internal_notes">Internal operations notes</label><textarea className="input" id="internal_notes" name="internal_notes" /></div>
      </ActionForm>
    </Card><p className="meta"><Link href="/sourcing">Return to demand</Link></p></div>
  </>;
}
