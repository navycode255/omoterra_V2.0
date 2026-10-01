import styles from './login.module.css';
import { LoginForm } from '@/components/register/pin-forms';

export const metadata = { title: 'Log in · Omoterra' };

export default function Login() {
  return <div className={styles.page}><svg className={styles.art} viewBox="0 0 1672 866" preserveAspectRatio="none" aria-hidden="true"><path d="M0 0H1672V108C1300 250 650 238 0 90Z" fill="#d4e4d6" opacity=".42"/><path d="M0 235C225 320 345 494 435 736L495 866H0Z" fill="#a1bf9c" opacity=".26"/><path d="M0 392C460 330 772 777 1333 704c137-18 240-60 339-105" fill="none" stroke="white" strokeWidth="1.5" opacity=".8"/><path d="M0 391C460 330 772 777 1333 704c137-18 240-60 339-105v267H0Z" fill="#c2d3ad" opacity=".12"/></svg><LoginForm /></div>;
}
