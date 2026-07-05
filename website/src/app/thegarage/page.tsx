import type { Metadata } from "next";
import Link from "next/link";
import {
  ArrowUpRight,
  Calendar,
  Mail,
  Rocket,
  Target,
  Users,
  Warehouse
} from "lucide-react";
import { SiteNav } from "../components/SiteNav";
import { garageAccelerator } from "./garageData";

export const metadata: Metadata = {
  title: "The Garage | CAOCAP Accelerator",
  description:
    "The Garage is the CAOCAP accelerator for creative builders learning software by making real apps.",
  openGraph: {
    title: "The Garage | CAOCAP Accelerator",
    description:
      "Program details, cohort updates, and applications for the CAOCAP accelerator.",
    type: "website",
    url: "https://www.azzam.ai/caocap/thegarage",
    siteName: "CAOCAP"
  }
};

const pillarIcons = [Warehouse, Users, Rocket] as const;

function StatusBadge({ label }: { label: string }) {
  return <span className="garage-status">{label}</span>;
}

export default function TheGaragePage() {
  const program = garageAccelerator;
  const hasApplicationLink = Boolean(program.applicationUrl);

  return (
    <main className="garage-page">
      <SiteNav showContribute={false} />

      <section className="garage-hero">
        <div className="garage-hero-icon" aria-hidden="true">
          <Warehouse size={30} />
        </div>
        <p className="eyebrow">{program.eyebrow}</p>
        <h1>{program.name}</h1>
        <StatusBadge label={program.statusLabel} />
        <p>{program.tagline}</p>
        <p className="garage-cohort">{program.cohortLabel}</p>
      </section>

      <section className="garage-panel">
        <div className="section-heading">
          <p className="eyebrow">Overview</p>
          <h2>Where CAOCAP builders learn in public.</h2>
        </div>
        <p className="garage-lede">{program.overview}</p>

        <div className="garage-stats" aria-label="Program snapshot">
          {program.stats.map((stat) => (
            <div className="garage-stat" key={stat.label}>
              <span>{stat.label}</span>
              <strong>{stat.value}</strong>
            </div>
          ))}
        </div>
      </section>

      <section className="garage-panel">
        <div className="section-heading">
          <p className="eyebrow">What you get</p>
          <h2>Studio, mentorship, and real output.</h2>
        </div>
        <div className="feature-grid garage-feature-grid">
          {program.pillars.map((pillar, index) => {
            const Icon = pillarIcons[index] ?? Target;

            return (
              <article className="feature-card" key={pillar.title}>
                <Icon aria-hidden="true" size={24} />
                <h3>{pillar.title}</h3>
                <p>{pillar.detail}</p>
              </article>
            );
          })}
        </div>
      </section>

      <section className="garage-panel">
        <div className="section-heading">
          <p className="eyebrow">Who it&apos;s for</p>
          <h2>Built for creative builders.</h2>
        </div>
        <p className="garage-lede">{program.audience}</p>
      </section>

      <section className="garage-panel">
        <div className="section-heading">
          <p className="eyebrow">Timeline</p>
          <h2>Key milestones for {program.cohortLabel}.</h2>
        </div>
        <ol className="garage-timeline">
          {program.timeline.map((item) => (
            <li className="garage-timeline-item" key={item.title}>
              <div className="garage-timeline-date">
                <Calendar aria-hidden="true" size={16} />
                <span>{item.date}</span>
              </div>
              <div>
                <h3>{item.title}</h3>
                <p>{item.detail}</p>
              </div>
            </li>
          ))}
        </ol>
      </section>

      <section className="garage-cta">
        <Rocket aria-hidden="true" size={28} />
        <h2>{hasApplicationLink ? program.applicationCta : "Applications opening soon"}</h2>
        <p>
          {hasApplicationLink
            ? "Ready to build in The Garage? Submit your application for the next cohort."
            : "Program dates and the application form will be posted here. Reach out if you want early access."}
        </p>
        <div className="garage-cta-actions">
          {hasApplicationLink ? (
            <a
              className="garage-apply-button"
              href={program.applicationUrl ?? undefined}
              target="_blank"
              rel="noreferrer"
            >
              {program.applicationCta}
              <ArrowUpRight aria-hidden="true" size={18} />
            </a>
          ) : (
            <a className="garage-apply-button garage-apply-button-muted" href={`mailto:${program.contactEmail}`}>
              <Mail aria-hidden="true" size={18} />
              {program.contactEmail}
            </a>
          )}
          <Link className="garage-secondary-link" href="/">
            Back to CAOCAP
          </Link>
        </div>
      </section>

      <footer className="site-footer garage-footer">
        <div className="footer-content">
          <p>© 2026 Azzam Alrashed. The Garage · CAOCAP Accelerator.</p>
          <div className="footer-links">
            <Link href="/">Home</Link>
            <Link href="/learn">Learn</Link>
            <Link href="/support">Support</Link>
          </div>
        </div>
      </footer>
    </main>
  );
}
