import Link from 'next/link';
import { ActionForm } from '@/components/form';
import { Card, PageHeader } from '@/components/ui';
import { createSupplier } from '@/lib/actions';

export const metadata = { title: 'Add supplier · Omoterra Operations' };
const categories = [
  ['broilers', 'Broilers', 'birds'], ['local_chicken', 'Local chicken', 'birds'],
  ['layers', 'Layers', 'birds'], ['eggs', 'Eggs', 'trays'], ['goats', 'Goats', 'animals'],
  ['cattle', 'Cattle', 'animals'], ['chicken_meat', 'Chicken meat', 'kg'],
  ['beef', 'Beef', 'kg'], ['goat_meat', 'Goat meat', 'kg'],
];

export default function AddSupplier() {
  return <>
    <div className="topbar"><PageHeader title="Add supplier" subtitle="Create the supplier's permanent Omoterra account and operating profile." /><Link className="button" href="/suppliers">Back to suppliers</Link></div>
    <div className="workspace">
      <ActionForm action={createSupplier} label="Register supplier">
        <Card title="Identity and location">
          <div className="grid-2">
            <div className="field"><label htmlFor="public_alias">Farm / supplier name</label><input className="input" id="public_alias" name="public_alias" minLength={2} maxLength={120} required /></div>
            <div className="field"><label htmlFor="legal_name">Legal / full name</label><input className="input" id="legal_name" name="legal_name" minLength={2} required /></div>
            <div className="field"><label htmlFor="phone">Primary phone</label><input className="input" id="phone" name="phone" placeholder="+255712345678" pattern="\\+255[67][0-9]{8}" required /></div>
            <div className="field"><label htmlFor="alternate_phone">Alternate phone (optional)</label><input className="input" id="alternate_phone" name="alternate_phone" /></div>
            <div className="field"><label htmlFor="region">Region</label><input className="input" id="region" name="region" required /></div>
            <div className="field"><label htmlFor="district">District</label><input className="input" id="district" name="district" required /></div>
            <div className="field"><label htmlFor="general_area">General area</label><input className="input" id="general_area" name="general_area" /></div>
          </div>
        </Card>
        <Card title="Supply and normal production">
          <p className="meta">Select every product the supplier normally produces. Record typical capacity only when the supplier has shared it.</p>
          <div className="grid-3">{categories.map(([key, label, unit]) => <div key={key} className="field">
            <label><input type="checkbox" name="categories" value={key} /> {label}</label>
            <label className="meta" htmlFor={`capacity_${key}`}>Typical capacity ({unit} / cycle)</label>
            <input className="input" id={`capacity_${key}`} name={`capacity_${key}`} type="number" min="0" step="any" />
          </div>)}</div>
          <div className="grid-2">
            <div className="field"><label htmlFor="primary_category">Main category</label><select className="input" id="primary_category" name="primary_category" required><option value="">Choose…</option>{categories.map(([key,label])=><option key={key} value={key}>{label}</option>)}</select></div>
            <div className="field"><label htmlFor="production_frequency">Production cycle / frequency</label><input className="input" id="production_frequency" name="production_frequency" placeholder="e.g. every 6 weeks" /></div>
          </div>
        </Card>
        <Card title="Pickup and operations">
          <div className="grid-2">
            <div className="field"><label htmlFor="internal_pickup_address">Exact pickup location (private)</label><textarea className="input" id="internal_pickup_address" name="internal_pickup_address" required /></div>
            <div className="field"><label htmlFor="pickup_instructions">Pickup instructions</label><textarea className="input" id="pickup_instructions" name="pickup_instructions" /></div>
            <div className="field"><label><input type="checkbox" name="omoterra_pickup" /> Omoterra can collect from this location</label></div>
            <div className="field"><label><input type="checkbox" name="supplier_transport" /> Supplier can arrange transport</label></div>
            <div className="field"><label htmlFor="preferred_contact_method">Preferred contact</label><select className="input" id="preferred_contact_method" name="preferred_contact_method"><option value="phone">Phone call</option><option value="whatsapp">WhatsApp</option><option value="sms">Text message</option></select></div>
            <div className="field"><label htmlFor="supply_forms">Supply type</label><select className="input" id="supply_forms" name="supply_forms" multiple><option value="live">Live</option><option value="dressed">Dressed</option><option value="chilled">Chilled</option><option value="frozen">Frozen</option></select></div>
          </div>
          <div className="field"><label htmlFor="operating_notes">Operating schedule and notes</label><textarea className="input" id="operating_notes" name="operating_notes" /></div>
          <div className="field"><label htmlFor="internal_notes">Private staff notes</label><textarea className="input" id="internal_notes" name="internal_notes" /></div>
          <div className="field"><label htmlFor="evidence_photos">Farm / location photos (up to 8, 8 MB each)</label><input className="input" id="evidence_photos" name="evidence_photos" type="file" accept="image/jpeg,image/png,image/webp" multiple /></div>
        </Card>
        <Card title="Current production (optional)">
          <p className="meta">Add a current or planned batch now. It will remain private until staff verifies it.</p>
          <div className="grid-3">
            <div className="field"><label htmlFor="current_category">Category</label><select className="input" id="current_category" name="current_category">{categories.map(([key,label])=><option key={key} value={key}>{label}</option>)}</select></div>
            <div className="field"><label htmlFor="current_quantity">Quantity (leave blank to skip)</label><input className="input" id="current_quantity" name="current_quantity" type="number" min="1" /></div>
            <div className="field"><label htmlFor="current_subtype">Breed / type</label><input className="input" id="current_subtype" name="current_subtype" /></div>
            <div className="field"><label htmlFor="current_age">Current age</label><input className="input" id="current_age" name="current_age" type="number" min="0" step="any" /></div>
            <div className="field"><label htmlFor="current_age_unit">Age unit</label><select className="input" id="current_age_unit" name="current_age_unit"><option value="weeks">Weeks</option><option value="days">Days</option><option value="months">Months</option></select></div>
            <div className="field"><label htmlFor="current_ready_date">Expected ready / collection date</label><input className="input" id="current_ready_date" name="current_ready_date" type="date" /></div>
            <div className="field"><label htmlFor="current_min_weight">Expected minimum weight (kg)</label><input className="input" id="current_min_weight" name="current_min_weight" type="number" min="0.001" step="any" /></div>
            <div className="field"><label htmlFor="current_max_weight">Expected maximum weight (kg)</label><input className="input" id="current_max_weight" name="current_max_weight" type="number" min="0.001" step="any" /></div>
            <div className="field"><label htmlFor="current_form">Live / dressed</label><select className="input" id="current_form" name="current_form"><option value="live">Live</option><option value="dressed">Dressed</option><option value="chilled">Chilled</option><option value="frozen">Frozen</option></select></div>
            <div className="field"><label htmlFor="current_asking_price">Agreed asking price (TZS / unit)</label><input className="input" id="current_asking_price" name="current_asking_price" type="number" min="0.01" step="any" /></div>
            <div className="field"><label htmlFor="current_photos">Current production photos (up to 8, 8 MB each)</label><input className="input" id="current_photos" name="current_photos" type="file" accept="image/jpeg,image/png,image/webp" multiple /></div>
          </div>
        </Card>
        <Card title="Next planned production (optional)">
          <p className="meta">Add a planned batch when quantity and expected availability are known.</p>
          <div className="grid-3">
            <div className="field"><label htmlFor="future_category">Category</label><select className="input" id="future_category" name="future_category">{categories.map(([key,label])=><option key={key} value={key}>{label}</option>)}</select></div>
            <div className="field"><label htmlFor="future_quantity">Planned quantity (leave blank to skip)</label><input className="input" id="future_quantity" name="future_quantity" type="number" min="1" /></div>
            <div className="field"><label htmlFor="future_subtype">Breed / type</label><input className="input" id="future_subtype" name="future_subtype" /></div>
            <div className="field"><label htmlFor="future_age">Current age (if placed)</label><input className="input" id="future_age" name="future_age" type="number" min="0" step="any" /></div>
            <div className="field"><label htmlFor="future_age_unit">Age unit</label><select className="input" id="future_age_unit" name="future_age_unit"><option value="weeks">Weeks</option><option value="days">Days</option><option value="months">Months</option></select></div>
            <div className="field"><label htmlFor="future_ready_date">Expected ready date</label><input className="input" id="future_ready_date" name="future_ready_date" type="date" /></div>
            <div className="field"><label htmlFor="future_min_weight">Expected minimum weight (kg)</label><input className="input" id="future_min_weight" name="future_min_weight" type="number" min="0.001" step="any" /></div>
            <div className="field"><label htmlFor="future_max_weight">Expected maximum weight (kg)</label><input className="input" id="future_max_weight" name="future_max_weight" type="number" min="0.001" step="any" /></div>
            <div className="field"><label htmlFor="future_form">Live / dressed</label><select className="input" id="future_form" name="future_form"><option value="live">Live</option><option value="dressed">Dressed</option><option value="chilled">Chilled</option><option value="frozen">Frozen</option></select></div>
            <div className="field"><label htmlFor="future_asking_price">Agreed asking price (TZS / unit)</label><input className="input" id="future_asking_price" name="future_asking_price" type="number" min="0.01" step="any" /></div>
            <div className="field"><label htmlFor="future_photos">Planned supply photos</label><input className="input" id="future_photos" name="future_photos" type="file" accept="image/jpeg,image/png,image/webp" multiple /></div>
          </div>
        </Card>
      </ActionForm>
    </div>
  </>;
}
