import { LegalPage } from '@/components/legal-page';
import { terms } from '@/lib/legal';

export const metadata = { title: 'Terms of Use · Omoterra', description: terms.summary };

export default function Terms() {
  return <LegalPage document={terms} current="terms" />;
}
