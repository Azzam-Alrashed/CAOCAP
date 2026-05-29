import Foundation

public enum AppActionCategory: String, Hashable {
    case navigation
    case project
    case assistant
}

public enum AppActionID: String, CaseIterable, Identifiable, Codable, Hashable {
    case goRoot = "go_root"
    case goBack = "go_back"
    case newProject = "new_project"
    case createNode = "create_node"
    case createTextNode = "create_text_node"
    case createCalculationNode = "create_calculation_node"
    case createDisplayNode = "create_display_node"
    case createNumberNode = "create_number_node"
    case createTableNode = "create_table_node"
    case createChartNode = "create_chart_node"
    case createFirebaseNode = "create_firebase_node"
    case summonCoCaptain = "summon_cocaptain"
    case openFile = "open_file"
    case toggleGrid = "toggle_grid"
    case shareProject = "share_project"
    case proSubscription = "pro_subscription"
    case signIn = "sign_in"
    case openSettings = "open_settings"
    case openProfile = "open_profile"
    case openProjectExplorer = "open_project_explorer"
    case moveNode = "move_node"
    case themeNode = "theme_node"
    case transformNode = "transform_node"
    case createAiAgentNode = "create_ai_agent_node"
    case help = "help"
    case organizeNodes = "organize_nodes"
    case openSnapshotBrowser = "open_snapshot_browser"
    case toggleHUD = "toggle_hud"
    case showActionsList = "show_actions_list"
    case createSubCanvas = "create_sub_canvas"

    public var id: String { rawValue }
}

public struct AppActionDefinition: Identifiable, Hashable {
    public let id: AppActionID
    public let title: String
    public let icon: String
    public let category: AppActionCategory
    /// Mutating actions change user data or project structure. Most require
    /// review, but small reversible workspace actions may opt into autonomous
    /// execution through `allowsAutonomousExecution`.
    public let isMutating: Bool
    /// Indicates whether trusted non-user callers, such as CoCaptain, may run
    /// this action without an explicit review item.
    public let allowsAutonomousExecution: Bool

    public init(
        id: AppActionID,
        title: String,
        icon: String,
        category: AppActionCategory,
        isMutating: Bool,
        allowsAutonomousExecution: Bool
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.category = category
        self.isMutating = isMutating
        self.allowsAutonomousExecution = allowsAutonomousExecution
    }

    public var localizedTitle: String {
        LocalizationManager.shared.localizedString(title)
    }
}

public enum AppActionSource: Hashable {
    case user
    case agentAutomatic
    case agentApproved
}

public struct AppActionResult: Hashable {
    public let actionID: AppActionID
    public let title: String
    public let executed: Bool
    public let message: String

    public init(actionID: AppActionID, title: String, executed: Bool, message: String) {
        self.actionID = actionID
        self.title = title
        self.executed = executed
        self.message = message
    }
}

@MainActor
public protocol AppActionPerforming: AnyObject {
    var availableActions: [AppActionDefinition] { get }
    func definition(for id: AppActionID) -> AppActionDefinition?
    @discardableResult
    func perform(_ id: AppActionID, source: AppActionSource, arguments: [String: String]?) -> AppActionResult
}

/// Central registry and execution boundary for commands. UI surfaces and agents
/// request actions by ID; this dispatcher owns whether they are configured and
/// safe to execute from the given source.
@MainActor
public final class AppActionDispatcher: AppActionPerforming {
    public private(set) var availableActions: [AppActionDefinition] = [
        AppActionDefinition(
            id: .goRoot,
            title: "Go to Root",
            icon: "house.fill",
            category: .navigation,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .goBack,
            title: "Go Back",
            icon: "arrow.left.circle",
            category: .navigation,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .newProject,
            title: "New Project",
            icon: "plus.circle.fill",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: false
        ),
        AppActionDefinition(
            id: .createNode,
            title: "Create New Node",
            icon: "plus.square",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: false
        ),
        AppActionDefinition(
            id: .createTextNode,
            title: "Create Text Node",
            icon: "text.cursor",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .createCalculationNode,
            title: "Create Calculation Node",
            icon: "plus.forwardslash.minus",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .createDisplayNode,
            title: "Create Display Node",
            icon: "opticaldisc.fill",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .createNumberNode,
            title: "Create Number Node",
            icon: "text.cursor",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .createTableNode,
            title: "Create Table Node",
            icon: "tablecells.fill",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .createChartNode,
            title: "Create Chart Node",
            icon: "chart.line.uptrend.xyaxis",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .createAiAgentNode,
            title: "Create AI Agent Node",
            icon: "brain.head.profile.fill",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .createFirebaseNode,
            title: "Create Firebase Node",
            icon: "flame.fill",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .summonCoCaptain,
            title: "Summon Co-Captain",
            icon: "sparkles",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .openFile,
            title: "Open File",
            icon: "doc.text.magnifyingglass",
            category: .project,
            isMutating: false,
            allowsAutonomousExecution: false
        ),
        AppActionDefinition(
            id: .toggleGrid,
            title: "Toggle Grid",
            icon: "grid",
            category: .navigation,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .shareProject,
            title: "Share Project",
            icon: "square.and.arrow.up",
            category: .project,
            isMutating: false,
            allowsAutonomousExecution: false
        ),
        AppActionDefinition(
            id: .proSubscription,
            title: "Pro Subscription",
            icon: "crown",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: false
        ),
        AppActionDefinition(
            id: .signIn,
            title: "Sign In",
            icon: "person.crop.circle.badge.checkmark",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: false
        ),
        AppActionDefinition(
            id: .openSettings,
            title: "Open Settings",
            icon: "gearshape.fill",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .openProfile,
            title: "Open Profile",
            icon: "person.fill",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .openProjectExplorer,
            title: "Project Explorer",
            icon: "folder.fill",
            category: .project,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .moveNode,
            title: "Move Node",
            icon: "arrow.up.and.down.and.arrow.left.and.right",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .themeNode,
            title: "Change Node Theme",
            icon: "paintbrush.fill",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: false
        ),
        AppActionDefinition(
            id: .transformNode,
            title: "Transform Node Type",
            icon: "arrow.triangle.2.circlepath",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: false
        ),
        AppActionDefinition(
            id: .help,
            title: "Help & Documentation",
            icon: "questionmark.circle",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .organizeNodes,
            title: "Organize Nodes",
            icon: "wand.and.stars",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .openSnapshotBrowser,
            title: "Browse Checkpoints",
            icon: "clock.arrow.circlepath",
            category: .project,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .toggleHUD,
            title: "Toggle HUD",
            icon: "menubar.rectangle",
            category: .navigation,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .showActionsList,
            title: "Show Actions List",
            icon: "list.bullet.rectangle.portrait",
            category: .navigation,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .createSubCanvas,
            title: "New Sub-Canvas",
            icon: "folder.fill.badge.plus",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: false
        )
    ]

    private var handlers: [AppActionID: ([String: String]?) -> String?] = [:]

    public init() {}

    /// Registers a simple parameter-free handler.
    public func register(_ id: AppActionID, handler: @escaping () -> Void) {
        handlers[id] = { _ in
            handler()
            return nil
        }
    }

    /// Registers a handler that accepts arguments.
    public func register(_ id: AppActionID, handler: @escaping ([String: String]?) -> Void) {
        handlers[id] = { arguments in
            handler(arguments)
            return nil
        }
    }

    /// Registers a handler that accepts arguments and returns a custom status message.
    public func register(_ id: AppActionID, handler: @escaping ([String: String]?) -> String?) {
        handlers[id] = handler
    }

    public func definition(for id: AppActionID) -> AppActionDefinition? {
        availableActions.first(where: { $0.id == id })
    }

    /// Executes an action if configured. Automatic agent calls are blocked
    /// unless the action has explicitly opted into autonomous execution.
    @discardableResult
    public func perform(_ id: AppActionID, source: AppActionSource, arguments: [String: String]? = nil) -> AppActionResult {
        guard let definition = definition(for: id) else {
            return AppActionResult(
                actionID: id,
                title: id.rawValue,
                executed: false,
                message: LocalizationManager.shared.localizedString("Action unavailable.")
            )
        }

        if source == .agentAutomatic {
            guard definition.allowsAutonomousExecution else {
                return AppActionResult(
                    actionID: definition.id,
                    title: definition.localizedTitle,
                    executed: false,
                    message: LocalizationManager.shared.localizedString("Action requires approval.")
                )
            }
        }

        guard let handler = handlers[id] else {
            return AppActionResult(
                actionID: definition.id,
                title: definition.localizedTitle,
                executed: false,
                message: LocalizationManager.shared.localizedString("Action is not configured.")
            )
        }

        let customMessage = handler(arguments)
        let defaultMessage = LocalizationManager.shared.localizedString("appAction.executedMessage", arguments: [definition.localizedTitle])
        
        return AppActionResult(
            actionID: definition.id,
            title: definition.localizedTitle,
            executed: true,
            message: customMessage ?? defaultMessage
        )
    }
}
