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
          <p>We're here to help you build in the spatial era.</p>
        </div>

        <section className="legal-content">
          <div className="support-grid">
            <div className="support-card">
              <div className="support-card-icon">
                <Mail size={24} />
              </div>
              <h3>Email Support</h3>
              <p>For account issues, billing questions, or technical bugs.</p>
              <a href="mailto:support@caocap.app" className="support-link">support@caocap.app</a>
            </div>

            <div className="support-card">
              <div className="support-card-icon">
                <MessageSquare size={24} />
              </div>
              <h3>GitHub Issues</h3>
              <p>Report bugs or request features in the open.</p>
              <a href="https://github.com/Azzam-Alrashed/CAOCAP-Ficruty/issues" target="_blank" rel="noreferrer" className="support-link">Open Issue</a>
            </div>

            <div className="support-card">
              <div className="support-card-icon">
                <Twitter size={24} />
              </div>
              <h3>X / Twitter</h3>
              <p>Follow for updates and quick questions.</p>
              <a href="https://twitter.com/azzamalrashed" target="_blank" rel="noreferrer" className="support-link">@azzamalrashed</a>
            </div>
          </div>

          <div className="support-faq">
            <h2>Frequently Asked Questions</h2>
            
            <div className="faq-item">
              <h3>Is my code private?</h3>
              <p>Yes. Your code is stored locally on your device. It is only synced to our servers if you sign in to an account for cross-device access.</p>
            </div>

            <div className="faq-item">
              <h3>Does CoCaptain use my data for training?</h3>
              <p>No. We use Google Gemini via Firebase AI Logic. Your project context is processed transiently and is not used to train global AI models.</p>
            </div>

            <div className="faq-item">
              <h3>How do I cancel my Pro subscription?</h3>
              <p>Subscriptions are managed directly through your Apple ID settings. Open the App Store app, tap your profile, and select "Subscriptions".</p>
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}
