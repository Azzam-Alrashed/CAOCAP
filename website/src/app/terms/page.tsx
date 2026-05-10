import { FileText } from "lucide-react";
import { SiteNav } from "../components/SiteNav";

export default function TermsPage() {
  return (
    <main className="legal-page">
      <SiteNav showContribute={false} />

      <div className="legal-container">
        <div className="legal-header">
          <div className="legal-icon">
            <FileText size={32} />
          </div>
          <h1>Terms of Service</h1>
          <p>Effective Date: April 25, 2026</p>
        </div>

        <section className="legal-content">
          <h2>1. Acceptance of Terms</h2>
          <p>
            By downloading or using CAOCAP, you agree to these Terms of Service and our Privacy Policy. If you do not agree, do not use the application.
          </p>

          <h2>2. License</h2>
          <p>
            CAOCAP is distributed under the GNU General Public License v3.0 as described in the public repository. App Store distribution, Apple platform terms, and third-party service terms may also apply when you install or use the app.
          </p>

          <h2>3. Pro Subscriptions</h2>
          <p>
            CAOCAP Pro is a subscription service. Payments are handled via Apple&apos;s StoreKit 2. Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. You can manage your subscription in your App Store Account Settings.
          </p>

          <h2>4. User Content</h2>
          <p>
            You retain full ownership of all code, designs, and requirements created within CAOCAP. You are solely responsible for ensuring your content does not violate any laws or third-party rights.
          </p>

          <h2>5. AI CoCaptain</h2>
          <p>
            CoCaptain responses and AI-generated suggestions are provided &quot;as is.&quot; CAOCAP is designed to stage meaningful code and SRS changes for review, but you are responsible for deciding whether to apply or use AI-proposed work.
          </p>

          <h2>6. Limitation of Liability</h2>
          <p>
            CAOCAP is provided &quot;as is&quot; without warranties of any kind. We are not liable for any loss of data, profits, or damages resulting from the use or inability to use the software.
          </p>

          <h2>7. Changes to Terms</h2>
          <p>
            We may update these terms from time to time. Continued use of the app after updates constitutes acceptance of the new terms.
          </p>
        </section>
      </div>
    </main>
  );
}
