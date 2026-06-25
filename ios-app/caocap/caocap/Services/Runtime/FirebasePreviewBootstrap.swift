import Foundation

/// Builds HTML snippets so a Mini-App preview can load Firebase Web compat SDK
/// and `initializeApp` from the Mini-App's embedded Firebase Web config JSON.
public enum FirebasePreviewBootstrap {

    /// Placeholder JSON for a Mini-App Firebase config (replace with values from the console).
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

    /// One-line status for the canvas card (no API keys).
    public static func canvasSummaryLine(for node: SpatialNode) -> String {
        guard let miniApp = node.miniApp else {
            return "Firebase config unavailable"
        }
        return canvasSummaryLine(for: miniApp)
    }

    public static func canvasSummaryLine(for miniApp: MiniAppState) -> String {
        guard let raw = miniApp.firebaseConfigText.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let pid = obj["projectId"] as? String,
              !pid.isEmpty
        else {
            return "Tap to paste Firebase Web config"
        }
        if let path = miniApp.firebaseFirestorePath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
            return "project: \(pid) · path: \(path)"
        }
        return "project: \(pid)"
    }

    /// Default Firestore + App compat scripts (pinned for stable preview).
    static let firebaseAppScriptURL = "https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js"
    static let firebaseFirestoreScriptURL = "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore-compat.js"

    /// Parsed `firebaseConfig` object suitable for `initializeApp`, or `nil`.
    public static func injectableFirebaseConfig(for miniApp: MiniAppState) -> [String: Any]? {
        let raw = miniApp.firebaseConfigText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let apiKey = obj["apiKey"] as? String,
              let projectId = obj["projectId"] as? String
        else { return nil }

        let keyTrim = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let pidTrim = projectId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyTrim.isEmpty, !pidTrim.isEmpty else { return nil }

        // Template / placeholder nodes from the app scaffold must not block a second real node.
        if keyTrim.uppercased().contains("YOUR") { return nil }
        if pidTrim.lowercased() == "your-project-id" { return nil }

        return obj
    }

    /// Returns HTML to inject at the start of `<head>`, or `nil` if the Mini-App has no valid config.
    static func headInjectionHTML(from miniApp: MiniAppState) -> String? {
        guard let obj = injectableFirebaseConfig(for: miniApp),
              let jsonData = try? JSONSerialization.data(withJSONObject: obj, options: []),
              let b64 = Optional(jsonData.base64EncodedString())
        else { return nil }

        let pathAttr = (miniApp.firebaseFirestorePath ?? "")
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        // Base64 avoids `</script>` breaking the document if JSON ever contained that sequence.
        return """
        <script type="text/plain" id="__caocap_fb_b64">\(b64)</script>
        <div id="__caocap_fb_path" data-collection="\(pathAttr)" hidden></div>
        <script src="\(firebaseAppScriptURL)"></script>
        <script src="\(firebaseFirestoreScriptURL)"></script>
        <script>
        (function(){
          window.__caocapFirestoreStatus = 'booting';
          window.__caocapFirestoreLastError = '';
          function decodeCfg(){
            var el=document.getElementById('__caocap_fb_b64');
            if(!el) return null;
            try { return JSON.parse(atob(el.textContent.trim())); } catch(e){
              window.__caocapFirestoreLastError = 'bad_config_json:' + (e && e.message ? e.message : 'parse');
              return null;
            }
          }
          var cfg=decodeCfg();
          if(typeof firebase==="undefined"){
            window.__caocapFirestoreStatus = 'sdk_missing';
            return;
          }
          if(!cfg||!cfg.apiKey){
            window.__caocapFirestoreStatus = 'no_config';
            return;
          }
          try {
            if(!firebase.apps||firebase.apps.length===0){ firebase.initializeApp(cfg); }
          } catch(e) {
            window.__caocapFirestoreStatus = 'init_failed';
            window.__caocapFirestoreLastError = (e && e.message) ? e.message : 'initializeApp';
            return;
          }
          try {
            window.__caocapFirestore = firebase.firestore();
            window.__caocapFirestoreStatus = 'ready';
          } catch(e) {
            window.__caocapFirestore = null;
            window.__caocapFirestoreStatus = 'firestore_failed';
            window.__caocapFirestoreLastError = (e && e.message) ? e.message : 'firestore';
          }
          var p=document.getElementById('__caocap_fb_path');
          window.__caocapFirestoreDefaultPath = (p&&p.getAttribute('data-collection'))?p.getAttribute('data-collection'):'';
        })();
        </script>
        """
    }
}
