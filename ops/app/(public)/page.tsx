import { Inter, Sora } from 'next/font/google';
import { Homepage } from '@/components/home/homepage';
const inter = Inter({ subsets: ['latin'], variable: '--font-home-inter', display: 'swap' });
const sora = Sora({ subsets: ['latin'], variable: '--font-home-heading', weight: ['600', '700'], display: 'swap' });
export const metadata = {
  title: 'Omoterra · Livestock Marketplace in Tanzania',
  description: 'Omoterra connects farmers, buyers and markets to make livestock supply simple and reliable across Tanzania.',
};
export default function MarketingHome() { return <Homepage fontClass={`${inter.variable} ${sora.variable}`}/>; }
