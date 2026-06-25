import Foundation
import CoreGraphics

public enum ProjectTemplate: String, CaseIterable, Identifiable, Codable {
    case helloWorld = "hello_world"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .helloWorld: return "Hello World"
        }
    }
    
    public var description: String {
        switch self {
        case .helloWorld: return "A simple HTML WebView preview with click interactions and PM/Engineer agents."
        }
    }
    
    public var icon: String {
        switch self {
        case .helloWorld: return "play.circle.fill"
        }
    }
    
    public var theme: NodeTheme {
        switch self {
        case .helloWorld: return .blue
        }
    }
}

public struct ProjectTemplateProvider {

    /// Returns the nodes configuration for the given template.
    public static func nodes(for template: ProjectTemplate) -> [SpatialNode] {
        switch template {
        case .helloWorld:
            return defaultNodes
        }
    }

    /// Returns a new set of interconnected nodes for the default project template.
    public static var defaultNodes: [SpatialNode] {
        let webViewId = UUID()
        let srsId = UUID()
        let codeId = UUID()

        return [
            SpatialNode(
                id: webViewId,
                type: .webView,
                position: CGPoint(x: 360, y: 0),
                title: "Live Preview",
                subtitle: "Your current build renders here.",
                icon: "play.circle.fill",
                theme: .blue
            ),
            SpatialNode(
                id: srsId,
                type: .srs,
                position: CGPoint(x: -420, y: 0),
                title: "Software Requirements (SRS)",
                subtitle: "Define intent, people, flow, and success.",
                icon: "doc.text.fill",
                theme: .purple,
                connectedNodeIds: [codeId],
                textContent: SRSScaffold.defaultText,
                srsReadinessState: SRSReadinessEvaluator().evaluate(text: SRSScaffold.defaultText, currentState: nil),
                agentProfile: AgentProfile(
                    systemPrompt: "You are the Product Manager. Your job is to refine the SRS and product intent. Ensure requirements are clear and executable.",
                    roleName: "PM Agent",
                    isAutoTriggerEnabled: false
                )
            ),
            SpatialNode(
                id: codeId,
                type: .code,
                position: CGPoint(x: -30, y: 0),
                title: "Code",
                subtitle: "HTML, CSS, and JavaScript in one file.",
                icon: "chevron.left.slash.chevron.right",
                theme: .orange,
                connectedNodeIds: [webViewId],
                textContent: defaultCode,
                agentProfile: AgentProfile(
                    systemPrompt: "You are an expert Frontend Engineer. You receive updates from the PM (SRS node). Your job is to strictly write the HTML/CSS/JS code to implement the requirements.",
                    roleName: "Engineer Agent",
                    isAutoTriggerEnabled: false
                )
            )
        ]
    }

    private static let defaultCode = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>My App</title>
        <style>
            body {
                background-color: #0d0d0d;
                color: #ffffff;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                overflow: hidden;
            }

            h1 {
                font-size: 3rem;
                background: linear-gradient(90deg, #00C9FF 0%, #92FE9D 100%);
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                cursor: pointer;
                transition: transform 0.1s ease-out, filter 0.3s ease;
            }

            h1:hover {
                filter: drop-shadow(0 0 10px rgba(0, 201, 255, 0.5));
            }
        </style>
    </head>
    <body>
        <h1>Hello World!</h1>

        <script>
            document.addEventListener('DOMContentLoaded', () => {
                const text = document.querySelector('h1');

                document.addEventListener('mousemove', (e) => {
                    const x = (window.innerWidth / 2 - e.pageX) / 25;
                    const y = (window.innerHeight / 2 - e.pageY) / 25;
                    text.style.transform = `translate(${x}px, ${y}px)`;
                });

                text.addEventListener('click', () => {
                    text.style.transform = 'scale(1.2)';
                    setTimeout(() => {
                        text.style.transform = 'scale(1)';
                    }, 150);
                });
            });
        </script>
    </body>
    </html>
    """
}
