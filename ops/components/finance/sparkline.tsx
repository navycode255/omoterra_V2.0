// A small trend line with a soft fill, drawn from real daily values (oldest
// first). Flat or empty series draw a flat line.
export function Sparkline({ values, tone = 'green', className }: { values: (string | number)[]; tone?: 'green' | 'red'; className?: string }) {
  const points = values.map(Number).filter((v) => Number.isFinite(v));
  if (points.length < 2) return null;
  const width = 120, height = 44, pad = 3;
  const min = Math.min(...points), max = Math.max(...points);
  const span = max - min || 1;
  const xy = points.map((v, i) => [(i / (points.length - 1)) * width, height - pad - ((v - min) / span) * (height - pad * 2)]);
  // A gentle curve through the points (midpoint smoothing), not a jagged polyline.
  const line = xy.map(([x, y], i) => {
    if (i === 0) return `M${x.toFixed(1)} ${y.toFixed(1)}`;
    const [px, py] = xy[i - 1];
    const mx = (px + x) / 2;
    return `C${mx.toFixed(1)} ${py.toFixed(1)} ${mx.toFixed(1)} ${y.toFixed(1)} ${x.toFixed(1)} ${y.toFixed(1)}`;
  }).join(' ');
  const color = tone === 'red' ? '#e0534c' : '#21a46a';
  const id = `spark-${tone}`;
  return (
    <svg className={className} viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" aria-hidden="true">
      <defs><linearGradient id={id} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={color} stopOpacity=".22" /><stop offset="1" stopColor={color} stopOpacity="0" /></linearGradient></defs>
      <path d={`${line} L${width} ${height} L0 ${height} Z`} fill={`url(#${id})`} />
      <path d={line} fill="none" stroke={color} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" vectorEffect="non-scaling-stroke" />
    </svg>
  );
}
