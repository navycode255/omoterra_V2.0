import Image from 'next/image';

/** A compact ring for pending form actions; inherits the button colour. */
export function LoadingSpinner({ size = 18, label }: { size?: number; label?: string }) {
  return <svg className="loading-ring" width={size} height={size} viewBox="0 0 24 24" fill="none"
    role={label ? 'img' : undefined} aria-label={label} aria-hidden={label ? undefined : true}>
    <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" opacity=".18"/>
    <path d="M12 3a9 9 0 0 1 9 9" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
  </svg>;
}

/** Spinner and label shown inside a submit button while its form is pending. */
export function Busy({ children }: { children: React.ReactNode }) {
  return <span className="busy-label"><LoadingSpinner size={16}/>{children}</span>;
}

/** Branded route fallback; the surrounding navigation remains interactive. */
export function PageLoader({ message = 'Loading latest records...' }: { message?: string }) {
  return <div className="page-loader" role="status" aria-live="polite" aria-atomic="true" aria-label={message}>
    <div className="page-loader-content">
      <span className="page-loader-mark" aria-hidden="true">
        <svg className="page-loader-orbit" viewBox="0 0 160 160" fill="none">
          <circle cx="80" cy="80" r="73" stroke="#eaf2ee" strokeWidth="6"/>
          <circle cx="80" cy="80" r="73" stroke="#c4e1d5" strokeWidth="6" strokeLinecap="round"
            strokeDasharray="58 401" transform="rotate(108 80 80)"/>
          <circle cx="80" cy="80" r="73" stroke="#008747" strokeWidth="6" strokeLinecap="round"
            strokeDasharray="58 401" transform="rotate(-70 80 80)"/>
        </svg>
        <span className="page-loader-disc">
          <Image src="/icon.png" width={64} height={64} alt="" priority />
        </span>
      </span>
    </div>
  </div>;
}
