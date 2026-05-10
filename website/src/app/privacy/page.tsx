import { Shield } from "lucide-react";
import { SiteNav } from "../components/SiteNav";

export default function PrivacyPage() {
  return (
    <main className="legal-page">
      <SiteNav showContribute={false} />

      <div className="legal-container">
        <div className="legal-header">
          <div className="legal-icon">
            <Shield size={32} />
          </div>
          <h1>Privacy Policy</h1>
          <p>Effective Date: April 25, 2026</p>
        </div>

        <section className="legal-content">
          <h2>1. Overview</h2>
          <p>
            At CAOCAP, we prioritize your privacy. As a spatial IDE built for local-first thinking, we minimize data collection and ensure you maintain control over your code and creative assets.
          </p>

          <h2>2. Data Collection</h2>
          <p>
            <strong>Authentication:</strong> We use Firebase Authentication to secure your account. This may collect your email address or unique identifiers provided by Apple, Google, or GitHub.
          </p>
          <p>
            <strong>Project Data:</strong> Your project files, nodes, SRS content, code, and previews are stored locally on your device in the current app. CAOCAP does not sell your project data.
          </p>

          <h2>3. AI Processing (CoCaptain)</h2>
          <p>
            When you explicitly use CoCaptain, relevant project context such as SRS text, code-node content, node inventory, and relationship metadata may be sent to Google Gemini through Firebase AI Logic to generate responses. CAOCAP does not send project content to AI services merely because you create or edit a local project.
          </p>

          <h2>4. Your Rights</h2>
          <p>
            You can export your work from the app and request account deletion from the &quot;Profile&quot; section. Account deletion removes your Firebase account record; local projects remain on your device unless you delete them there.
          </p>

          <h2>5. Contact</h2>
          <p>
            If you have questions about this policy, contact us at azzam.rar@gmail.com.
          </p>
        </section>
      </div>
    </main>
  );
}
