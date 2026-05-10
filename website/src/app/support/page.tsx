import { LifeBuoy, Mail, MessageSquare, Twitter } from "lucide-react";
import { SiteNav } from "../components/SiteNav";

export default function SupportPage() {
  return (
    <main className="legal-page">
      <SiteNav showContribute={false} />

      <div className="legal-container">
        <div className="legal-header">
          <div className="legal-icon">
            <LifeBuoy size={32} />
          </div>
          <h1>Support & Help</h1>
          <p>We&apos;re here to help you build in the spatial era.</p>
        </div>

        <section className="legal-content">
          <div className="support-grid">
            <div className="support-card">
              <div className="support-card-icon">
                <Mail size={24} />
              </div>
              <h3>Email Support</h3>
              <p>For account issues, billing questions, or technical bugs.</p>
              <a href="mailto:azzam.rar@gmail.com" className="support-link">azzam.rar@gmail.com</a>
            </div>

            <div className="support-card">
              <div className="support-card-icon">
                <MessageSquare size={24} />
              </div>
              <h3>GitHub Issues</h3>
              <p>Report bugs or request features in the open.</p>
              <a href="https://github.com/Azzam-Alrashed/CAOCAP/issues" target="_blank" rel="noreferrer" className="support-link">Open Issue</a>
            </div>

            <div className="support-card">
              <div className="support-card-icon">
                <Twitter size={24} />
              </div>
              <h3>X / Twitter</h3>
              <p>Follow for updates and quick questions.</p>
              <a href="https://twitter.com/Azzam_rar" target="_blank" rel="noreferrer" className="support-link">@Azzam_rar</a>
            </div>
          </div>

          <div className="support-faq">
            <h2>Frequently Asked Questions</h2>
            
            <div className="faq-item">
              <h3>Is my code private?</h3>
              <p>Your code, SRS, and project graph are stored locally on your device in the current app. Project context is sent to AI services only when you explicitly ask CoCaptain for help.</p>
            </div>

            <div className="faq-item">
              <h3>Does CoCaptain use my data for training?</h3>
              <p>CoCaptain uses Google Gemini through Firebase AI Logic to answer your request. CAOCAP only sends the project context needed for the CoCaptain action you start.</p>
            </div>

            <div className="faq-item">
              <h3>How do I cancel my Pro subscription?</h3>
              <p>Subscriptions are managed directly through your Apple ID settings. Open the App Store app, tap your profile, and select &quot;Subscriptions&quot;.</p>
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}
