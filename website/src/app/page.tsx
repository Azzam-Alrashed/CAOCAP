import {
  AppWindow,
  ArrowUpRight,
  BookOpen,
  Bot,
  Boxes,
  Code2,
  Github,
  Sparkles,
  TestTube2
} from "lucide-react";
import Link from "next/link";
import { SiteNav } from "./components/SiteNav";

const appStoreUrl = "https://apps.apple.com/us/app/caocap/id1447742145";
const testFlightUrl = "https://testflight.apple.com/join/aS7Jwlof";
const githubUrl = "https://github.com/Azzam-Alrashed/CAOCAP";

const ctas = [
  {
    label: "App Store",
    href: appStoreUrl,
    icon: AppWindow,
    ariaLabel: "Download CAOCAP on the App Store"
  },
  {
    label: "TestFlight",
    href: testFlightUrl,
    icon: TestTube2,
    ariaLabel: "Join the CAOCAP TestFlight beta"
  },
  {
    label: "GitHub",
    href: githubUrl,
    icon: Github,
    ariaLabel: "Star CAOCAP on GitHub and contribute"
  }
];

const features = [
  {
    title: "Learn by making",
    body: "Start from tiny real Mini-Apps, change what they do, and understand the software idea at the moment it becomes useful."
  },
  {
    title: "Keep software visible",
    body: "Use the spatial canvas to keep requirements, code, behavior, and live preview close enough to inspect as one working system."
  },
  {
    title: "Build with a mentor",
    body: "CoCaptain can help write, revise, debug, and explain while keeping meaningful code changes ready for human review."
  }
];

const stats = [
  "Native iOS and iPadOS",
  "Live WebKit preview",
  "Human-reviewed AI edits",
  "Built for creative builders"
];

function CtaButtons() {
  return (
    <div className="cta-row" aria-label="Primary actions">
      {ctas.map((cta) => {
        const Icon = cta.icon;

        return (
          <a
            className="cta-button"
            href={cta.href}
            key={cta.label}
            aria-label={cta.ariaLabel}
            target="_blank"
            rel="noreferrer"
          >
            <Icon aria-hidden="true" size={20} strokeWidth={2.2} />
            <span>{cta.label}</span>
            <ArrowUpRight aria-hidden="true" size={17} strokeWidth={2.2} />
          </a>
        );
      })}
    </div>
  );
}

function CanvasMockup() {
  return (
    <div className="canvas-shell" aria-label="CAOCAP spatial canvas preview">
      <div className="canvas-toolbar">
        <div>
          <span className="toolbar-kicker">Project</span>
          <strong>Launch page</strong>
        </div>
        <span className="toolbar-pill">Live</span>
      </div>
      <div className="canvas-stage">
        <svg
          className="canvas-lines"
          viewBox="0 0 640 460"
          fill="none"
          aria-hidden="true"
        >
          <path d="M161 106 C239 112 252 184 324 188" />
          <path d="M161 106 C244 78 372 82 475 114" />
          <path d="M324 188 C399 196 431 263 501 288" />
          <path d="M304 344 C367 329 427 313 501 288" />
        </svg>

        <article className="node node-srs">
          <span>SRS</span>
          <strong>What should this teach?</strong>
          <p>Capture the mission before the code hardens.</p>
        </article>

        <article className="node node-html">
          <span>HTML</span>
          <strong>Screen</strong>
          <p>Put the visible parts into place.</p>
        </article>

        <article className="node node-css">
          <span>CSS</span>
          <strong>Feel</strong>
          <p>Shape rhythm, hierarchy, and tone.</p>
        </article>

        <article className="node node-js">
          <span>JS</span>
          <strong>Behavior</strong>
          <p>Make the app remember and respond.</p>
        </article>

        <article className="preview-node">
          <span>Live Preview</span>
          <div className="phone-frame">
            <div className="mini-page">
              <div />
              <div />
              <div />
            </div>
          </div>
        </article>
      </div>
    </div>
  );
}

export default function Home() {
  return (
    <main>
      <section className="hero-section">
        <SiteNav homeHref="#top" />

        <div className="hero-grid" id="top">
          <div className="hero-copy">
            <p className="eyebrow">Learn software by building</p>
            <h1>CAOCAP</h1>
            <p className="hero-lede">
              A creative canvas where people build real Mini-Apps, learn how
              software works, and grow with an AI mentor beside them.
            </p>
            <CtaButtons />
          </div>
          <CanvasMockup />
        </div>
      </section>

      <section className="section-panel">
        <div className="section-heading">
          <p className="eyebrow">Creative software learning</p>
          <h2>Build real things while the ideas become visible.</h2>
        </div>
        <div className="feature-grid">
          {features.map((feature) => (
            <article className="feature-card" key={feature.title}>
              <Boxes aria-hidden="true" size={24} />
              <h3>{feature.title}</h3>
              <p>{feature.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="split-section">
        <div>
          <p className="eyebrow">CoCaptain</p>
          <h2>An AI mentor that sees the whole project graph.</h2>
        </div>
        <div className="assistant-panel">
          <div className="assistant-icon">
            <Bot aria-hidden="true" size={28} />
          </div>
          <p>
            CAOCAP is being shaped around grounded mentorship: requirements,
            code, relationships, and previews in one context window, with
            meaningful edits staged for review.
          </p>
          <span>Build, understand, keep going.</span>
        </div>
      </section>

      <section className="native-section">
        <div className="native-copy">
          <p className="eyebrow">Native foundation</p>
          <h2>Designed for touch, canvas thinking, and real devices.</h2>
          <p>
            CAOCAP is built natively for iPhone and iPad, using WebKit for live
            previews and a spatial canvas for learning by making.
          </p>
        </div>
        <div className="status-grid" aria-label="CAOCAP status">
          {stats.map((stat) => (
            <div className="status-item" key={stat}>
              <Sparkles aria-hidden="true" size={18} />
              <span>{stat}</span>
            </div>
          ))}
        </div>
      </section>

      <section className="learn-section">
        <div>
          <p className="eyebrow">Azzamification</p>
          <h2>Read the pivot behind the next chapter.</h2>
        </div>
        <Link className="learn-card" href="/learn">
          <BookOpen aria-hidden="true" size={28} />
          <span>Read the Azzamification vision</span>
          <ArrowUpRight aria-hidden="true" size={18} />
        </Link>
      </section>

      <section className="final-cta">
        <Code2 aria-hidden="true" size={30} />
        <h2>Start learning through the canvas.</h2>
        <p>
          Download CAOCAP, join the TestFlight, or help shape a more creative
          way into software on GitHub.
        </p>
        <CtaButtons />
      </section>

      <footer className="site-footer">
        <div className="footer-content">
          <p>© 2026 Azzam Alrashed. Built for the spatial era.</p>
          <div className="footer-links">
            <Link href="/support">Support</Link>
            <Link href="/learn">Learn</Link>
            <Link href="/privacy">Privacy Policy</Link>
            <Link href="/terms">Terms of Service</Link>
            <a href={githubUrl} target="_blank" rel="noreferrer">GitHub</a>
          </div>
        </div>
      </footer>
    </main>
  );
}
