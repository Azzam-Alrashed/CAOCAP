import Foundation
import CoreGraphics

public enum ProjectTemplate: String, CaseIterable, Identifiable, Codable {
    case helloWorld = "hello_world"
    case reactiveCalculator = "reactive_calculator"
    case businessAnalytics = "business_analytics"
    case aiPoet = "ai_poet"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .helloWorld: return "Hello World"
        case .reactiveCalculator: return "Reactive Calculator"
        case .businessAnalytics: return "Business Analytics"
        case .aiPoet: return "AI Creative Agent"
        }
    }
    
    public var description: String {
        switch self {
        case .helloWorld: return "A simple HTML WebView preview with click interactions and PM/Engineer agents."
        case .reactiveCalculator: return "Number nodes flowing reactive inputs into calculation and gauge display nodes."
        case .businessAnalytics: return "A CSV data table node feeding values directly into a custom chart node."
        case .aiPoet: return "Text prompt input feeding into a generative AI Agent node for structured responses."
        }
    }
    
    public var icon: String {
        switch self {
        case .helloWorld: return "play.circle.fill"
        case .reactiveCalculator: return "plus.forwardslash.minus"
        case .businessAnalytics: return "chart.bar.fill"
        case .aiPoet: return "brain.head.profile.fill"
        }
    }
    
    public var theme: NodeTheme {
        switch self {
        case .helloWorld: return .blue
        case .reactiveCalculator: return .orange
        case .businessAnalytics: return .purple
        case .aiPoet: return .indigo
        }
    }
}

public struct ProjectTemplateProvider {

    /// Returns the nodes configuration for the given template.
    public static func nodes(for template: ProjectTemplate) -> [SpatialNode] {
        switch template {
        case .helloWorld:
            return defaultNodes
        case .reactiveCalculator:
            return calculatorNodes
        case .businessAnalytics:
            return analyticsNodes
        case .aiPoet:
            return aiPoetNodes
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

    public static var calculatorNodes: [SpatialNode] {
        let revId = UUID()
        let costId = UUID()
        let calcId = UUID()
        let dispId = UUID()
        
        return [
            SpatialNode(
                id: revId,
                type: .number,
                position: CGPoint(x: -300, y: -100),
                title: "Revenue",
                subtitle: "Reactive input value",
                theme: .blue,
                nextNodeId: calcId,
                textContent: "1200"
            ),
            SpatialNode(
                id: costId,
                type: .number,
                position: CGPoint(x: -300, y: 100),
                title: "Costs",
                subtitle: "Reactive input value",
                theme: .blue,
                nextNodeId: calcId,
                textContent: "800"
            ),
            SpatialNode(
                id: calcId,
                type: .calculation,
                position: CGPoint(x: 0, y: 0),
                title: "Net Profit",
                subtitle: "Subtracts inputs in real-time",
                theme: .orange,
                nextNodeId: dispId,
                inputNodeIds: [revId, costId],
                operation: .subtract,
                outputValue: 400.0
            ),
            SpatialNode(
                id: dispId,
                type: .display,
                position: CGPoint(x: 300, y: 0),
                title: "Profit Gauge",
                subtitle: "Shows output visually",
                theme: .green,
                displayStyle: .gauge,
                outputValue: 400.0,
                inputNodeIds: [calcId]
            )
        ]
    }
    
    public static var analyticsNodes: [SpatialNode] {
        let tableId = UUID()
        let chartId = UUID()
        
        let csvContent = """
        Month,Sales,Expenses
        January,1200,800
        February,1500,950
        March,1800,1100
        April,2200,1300
        May,2500,1450
        June,3000,1800
        """
        
        return [
            SpatialNode(
                id: tableId,
                type: .table,
                position: CGPoint(x: -200, y: 0),
                title: "Monthly Sales",
                subtitle: "Monthly CSV ledger",
                theme: .cyan,
                nextNodeId: chartId,
                textContent: csvContent
            ),
            SpatialNode(
                id: chartId,
                type: .chart,
                position: CGPoint(x: 200, y: 0),
                title: "Sales Performance",
                subtitle: "Visual analytics trend",
                theme: .purple,
                chartStyle: .bar,
                chartXColumnIndex: 0,
                chartYColumnIndex: 1,
                chartHasHeaderRow: true,
                inputNodeIds: [tableId]
            )
        ]
    }
    
    public static var aiPoetNodes: [SpatialNode] {
        let inputId = UUID()
        let agentId = UUID()
        
        return [
            SpatialNode(
                id: inputId,
                type: .text,
                position: CGPoint(x: -220, y: 0),
                title: "Topic Input",
                subtitle: "Poem subject matter",
                theme: .blue,
                nextNodeId: agentId,
                textContent: "Space travel and the loneliness of Mars"
            ),
            SpatialNode(
                id: agentId,
                type: .aiAgent,
                position: CGPoint(x: 180, y: 0),
                title: "Poem Generator",
                subtitle: "Generative AI writing task",
                theme: .indigo,
                agentProfile: AgentProfile(
                    systemPrompt: "You are a creative poet. Write a beautiful 4-line poem based on the topic input.",
                    roleName: "Creative Poet",
                    isAutoTriggerEnabled: false
                ),
                promptTemplate: "Write a short, beautiful 4-line poem about the topic: {{Topic Input}}",
                inputNodeIds: [inputId]
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
