import { Inter } from 'next/font/google';
import { Homepage } from '@/components/home/homepage';
const inter = Inter({ subsets: ['latin'], variable: '--font-home-inter', display: 'swap' });
export const metadata = {
  title: 'Omoterra · Livestock Marketplace in Tanzania',
  description: 'Omoterra connects farmers, buyers and markets to make livestock supply simple and reliable across Tanzania.',
};
export default function MarketingHome() { return <Homepage fontClass={inter.variable}/>; }
