import { PageLoader } from '@/components/spinner';

/** Shared fallback for every route, including nested detail and edit pages. */
export default function RouteLoading() {
  return <PageLoader/>;
}
