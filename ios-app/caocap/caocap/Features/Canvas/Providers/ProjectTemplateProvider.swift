import Foundation
import CoreGraphics

public enum ProjectTemplate: String, CaseIterable, Identifiable, Codable {
    case helloWorld = "hello_world"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .helloWorld: return "Make It Remember"
        }
    }
    
    public var description: String {
        switch self {
        case .helloWorld: return "A tiny Mini-App mission about making a button remember taps."
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
        return [
            SpatialNode(
                type: .miniApp,
                position: CGPoint(x: 0, y: 0),
                title: "Make It Remember",
                subtitle: "Mission: make the button remember how many times it was tapped.",
                icon: NodeType.miniApp.defaultIcon,
                theme: .blue,
                miniApp: MiniAppState(
                    srsText: defaultSRSText,
                    srsReadinessState: SRSReadinessEvaluator().evaluate(text: defaultSRSText, currentState: nil),
                    codeText: defaultCode,
                    firebaseConfigText: FirebasePreviewBootstrap.placeholderConfigJSON()
                ),
                agentProfile: AgentProfile(
                    systemPrompt: "You are a Mini-App Mentor. Help the user complete the Make It Remember mission, explain state in beginner-friendly language, and keep all code changes human-reviewed before they are applied.",
                    roleName: "Mini-App Mentor",
                    isAutoTriggerEnabled: false
                )
            )
        ]
    }

    public static let defaultSRSText = """
    # Intent
    Make this button remember how many times it was tapped.

    ## Why It Matters
    The user wants to feel the first real software idea: apps can remember values while they run. In software, that memory is called state.

    ## People
    - Primary user: A creative builder learning how software works by changing a tiny real app.
    - Moment of use: The user's first CAOCAP mission, right after opening the Mini-App preview.

    ## Core Flow
    1. The user runs the Mini-App and sees a button with a count.
    2. The user taps the button and notices the count should change.
    3. The user edits the code or asks CoCaptain to help the button remember each tap.
    4. The preview confirms the count updates after every tap.

    ## Requirements
    - The interface must make the button and count easy to understand.
    - The app should keep a named JavaScript value for the tap count while the app is running.
    - The screen should update when the user taps the button.
    - CoCaptain should explain the change as state after the user sees why remembering matters.

    ## Acceptance Checks
    - [ ] A first-time user understands the mission without knowing the word state.
    - [ ] Tapping the button updates the visible count.
    - [ ] The code contains a named value that stores the count while the app runs.
    - [ ] CoCaptain can explain what changed without auto-applying code edits.

    ## Constraints
    - Keep the first mission small enough to finish in one short session.
    - Use one HTML file with inline CSS and JavaScript.
    - Do not add external dependencies.
    """

    public static let defaultCode = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Make It Remember</title>
        <style>
            :root {
                color-scheme: dark;
            }

            body {
                background: #101820;
                color: #f8fafc;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                padding: 24px;
                box-sizing: border-box;
            }

            main {
                width: min(100%, 420px);
                display: grid;
                gap: 18px;
                text-align: center;
            }

            .mission {
                color: #38bdf8;
                font-size: 0.8rem;
                font-weight: 700;
                letter-spacing: 0.08em;
                text-transform: uppercase;
            }

            h1 {
                margin: 0;
                font-size: clamp(2.1rem, 12vw, 4.2rem);
                line-height: 0.95;
            }

            p {
                margin: 0;
                color: #cbd5e1;
                font-size: 1rem;
                line-height: 1.55;
            }

            button {
                border: 0;
                border-radius: 16px;
                background: #f8fafc;
                color: #101820;
                font: inherit;
                font-weight: 800;
                padding: 18px 22px;
                cursor: pointer;
                box-shadow: 0 18px 40px rgba(0, 0, 0, 0.28);
                transition: transform 0.16s ease, box-shadow 0.16s ease;
            }

            button:active {
                transform: translateY(2px) scale(0.99);
                box-shadow: 0 10px 24px rgba(0, 0, 0, 0.24);
            }

            .counter {
                border: 1px solid rgba(148, 163, 184, 0.35);
                border-radius: 18px;
                padding: 16px;
                background: rgba(15, 23, 42, 0.72);
            }

            .count {
                display: block;
                color: #facc15;
                font-size: 3rem;
                font-weight: 900;
                line-height: 1;
            }
        </style>
    </head>
    <body>
        <main>
            <span class="mission">Make It Remember</span>
            <h1>Can this button remember?</h1>
            <p>Tap the button. Your mission is to make the count remember every tap while the app is running.</p>

            <button id="tapButton">Tap me</button>

            <div class="counter" aria-live="polite">
                <span class="count" id="tapCount">0</span>
                <p>taps remembered</p>
            </div>
        </main>

        <script>
            document.addEventListener('DOMContentLoaded', () => {
                const button = document.querySelector('#tapButton');
                const countLabel = document.querySelector('#tapCount');

                // Mission: create a value named tapCount, update it on each tap,
                // then show the new value in countLabel.

                button.addEventListener('click', () => {
                    countLabel.textContent = '0';
                });
            });
        </script>
    </body>
    </html>
    """
}
