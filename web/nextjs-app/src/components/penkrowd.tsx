import Link from "next/link";
import type { ButtonHTMLAttributes, ReactNode } from "react";

type Accent = "cyan" | "yellow" | "orange" | "purple" | "red";

export function AnimatedActionButton({
  children,
  href,
  color = "white",
  fullWidth = false,
  className = "",
  ...buttonProps
}: {
  children: ReactNode;
  href?: string;
  color?: Accent | "black" | "white";
  fullWidth?: boolean;
  className?: string;
} & ButtonHTMLAttributes<HTMLButtonElement>) {
  const classes = ["pk-action", `pk-${color}`, fullWidth ? "pk-full" : "", className].filter(Boolean).join(" ");

  if (href) {
    return (
      <Link className={classes} href={href}>
        {children}
      </Link>
    );
  }

  return (
    <button className={classes} {...buttonProps}>
      {children}
    </button>
  );
}

export function PenkrowdCard({
  id,
  children,
  accent,
  className = "",
}: {
  id?: string;
  children: ReactNode;
  accent?: Accent;
  className?: string;
}) {
  return (
    <section id={id} className={["pk-card", accent ? `pk-accent-${accent}` : "", className].filter(Boolean).join(" ")}>
      {children}
    </section>
  );
}

export function SectionCard({
  id,
  title,
  subtitle,
  action,
  children,
  accent,
  className = "",
}: {
  id?: string;
  title: string;
  subtitle?: string;
  action?: ReactNode;
  children: ReactNode;
  accent?: Accent;
  className?: string;
}) {
  return (
    <PenkrowdCard accent={accent} className={className} id={id}>
      <div className="pk-section-head">
        <div>
          <h2>{title}</h2>
          {subtitle ? <p>{subtitle}</p> : null}
        </div>
        {action}
      </div>
      {children}
    </PenkrowdCard>
  );
}

export function DetailHeaderCard({
  title,
  subtitle,
  fallbackLetter,
  status,
  accent,
}: {
  title: string;
  subtitle?: string;
  fallbackLetter: string;
  status?: ReactNode;
  accent?: Accent;
}) {
  return (
    <PenkrowdCard accent={accent} className="pk-detail-card">
      <div className="pk-avatar">{fallbackLetter.slice(0, 1).toUpperCase()}</div>
      <div className="pk-detail-copy">
        <strong>{title}</strong>
        {subtitle ? <p>{subtitle}</p> : null}
      </div>
      {status}
    </PenkrowdCard>
  );
}

export function AnimatedTabBar({ tabs, selectedIndex = 0 }: { tabs: string[]; selectedIndex?: number }) {
  return (
    <div className="pk-tabs" role="tablist">
      <i style={{ left: `${(100 / tabs.length) * selectedIndex}%`, width: `${100 / tabs.length}%` }} />
      {tabs.map((tab, index) => (
        <button className={index === selectedIndex ? "is-selected" : ""} key={tab}>
          {tab}
        </button>
      ))}
    </div>
  );
}

export function RadialStatGauge({
  value,
  max,
  label,
  accent = "cyan",
}: {
  value: number | null | undefined;
  max: number;
  label: string;
  accent?: Accent;
}) {
  const progress = value && max > 0 ? Math.max(0, Math.min(100, (value / max) * 100)) : 0;
  return (
    <div className={`pk-gauge pk-${accent}`}>
      <svg viewBox="0 0 120 120" aria-hidden="true">
        <circle className="pk-gauge-track" cx="60" cy="60" r="44" />
        <circle className="pk-gauge-progress" cx="60" cy="60" r="44" pathLength="100" style={{ strokeDasharray: `${progress} 100` }} />
      </svg>
      <strong>{value == null ? "—" : value.toFixed(value >= 10 ? 0 : 1)}</strong>
      <span>{label}</span>
    </div>
  );
}

export function StatusChip({ children, tone = "white" }: { children: ReactNode; tone?: Accent | "white" | "black" }) {
  return <span className={`pk-chip pk-${tone}`}>{children}</span>;
}
