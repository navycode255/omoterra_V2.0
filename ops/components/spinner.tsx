// Omoterra's loading mark: a trail of cloven hoofprints walking a circle. The
// freshest print is darkest and older ones fade, so it reads as motion even at
// button size. Colour follows `currentColor`, so it works on any surface.

const STEPS = 8;

// One cloven print, pointing up: two toes tapering to the front, round at the heel.
const TOE = 'M-0.6 -4.4C-2.4 -3.6-3.8 -0.6-3.5 2C-3.3 4-1.5 4.5-0.6 3.3Z';

function Hoofprint() {
  return <g>
    <path d={TOE}/>
    <path d={TOE} transform="scale(-1 1)"/>
  </g>;
}

export function HoofSpinner({ size = 18, label }: { size?: number; label?: string }) {
  return <svg className="hoof-spinner" width={size} height={size} viewBox="-20 -20 40 40" fill="currentColor"
    role={label ? 'img' : undefined} aria-label={label} aria-hidden={label ? undefined : true}>
    {Array.from({ length: STEPS }, (_, step) => {
      // Alternate left and right feet a little either side of the path.
      const radius = step % 2 ? 12.5 : 15.5;
      return <g key={step} className="hoof-step" style={{ animationDelay: `${(step - STEPS) * 0.15}s` }}
        transform={`rotate(${step * (360 / STEPS)}) translate(0 ${-radius}) rotate(90) scale(.9)`}>
        <Hoofprint/>
      </g>;
    })}
  </svg>;
}

/** Spinner and label shown inside a submit button while its form is pending. */
export function Busy({ children }: { children: React.ReactNode }) {
  return <span className="busy-label"><HoofSpinner size={16}/>{children}</span>;
}

/** Full-area loader for route segments that have no skeleton. */
export function PageLoader({ message = 'Loading…' }: { message?: string }) {
  return <div className="page-loader" role="status" aria-live="polite">
    <span className="page-loader-mark"><HoofSpinner size={56}/></span>
    <span className="page-loader-text">{message}</span>
  </div>;
}
