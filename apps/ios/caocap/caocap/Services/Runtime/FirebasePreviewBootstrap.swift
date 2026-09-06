import Foundation

/// Leftover Firebase preview helpers. Mini-App HTML preview is gone; these
/// methods stay only so older call sites can compile without Mini-App state.
public enum FirebasePreviewBootstrap {

    /// Placeholder JSON kept for leftover tests and unused call sites.
    public static func placeholderConfigJSON() -> String {
        """
        {
          "apiKey": "YOUR_WEB_API_KEY",
          "authDomain": "your-project.firebaseapp.com",
          "projectId": "your-project-id",
          "storageBucket": "your-project.appspot.com",
          "messagingSenderId": "000000000000",
          "appId": "1:000000000000:web:xxxxxxxx"
        }
        """
    }

    public static func canvasSummaryLine(for node: SpatialNode) -> String {
        _ = node
        return "Firebase config unavailable"
    }
}
