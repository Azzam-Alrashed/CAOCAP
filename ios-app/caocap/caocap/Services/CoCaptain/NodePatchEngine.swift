import Foundation

/// The kind of text transformation a `NodePatchOperation` should perform.
public enum NodePatchOperationType: String, Codable, Hashable {
    /// Discard all existing text and set the node section to `content`.
    case replaceAll = "replace_all"
    /// Locate the first occurrence of `target` and replace it with `content`.
    case replaceExact = "replace_exact"
    /// Insert `content` immediately before the first occurrence of `target`.
    case insertBeforeExact = "insert_before_exact"
    /// Insert `content` immediately after the first occurrence of `target`.
    case insertAfterExact = "insert_after_exact"
    /// Add `content` at the end of the existing text.
    case append
    /// Add `content` at the beginning of the existing text.
    case prepend
}

/// A single text transformation to apply to a node section (SRS or code).
public struct NodePatchOperation: Codable, Hashable {
    /// How the text should be modified.
    public let type: NodePatchOperationType
    /// The exact substring to locate for `replaceExact`, `insertBeforeExact`,
    /// and `insertAfterExact` operations. Unused by `replaceAll`, `append`, and `prepend`.
    public let target: String?
    /// The text to write as part of this operation.
    public let content: String

    public init(type: NodePatchOperationType, target: String? = nil, content: String) {
        self.type = type
        self.target = target
        self.content = content
    }
}

/// Errors that can occur when resolving a target node or applying patch operations.
public enum NodePatchError: LocalizedError, Hashable {
    /// No node with the expected `NodeRole` exists on the canvas.
    case missingNode(NodeRole)
    /// A specific node UUID was requested but not found in the active project.
    case missingNodeID(UUID)
    /// An exact-match operation could not find its target substring in the existing text.
    case conflict(String)

    public var errorDescription: String? {
        switch self {
        case .missingNode(let role):
            return LocalizationManager.shared.localizedString("Missing %@ node.", arguments: [role.localizedDisplayName])
        case .missingNodeID:
            return LocalizationManager.shared.localizedString("The targeted node could not be found.")
        case .conflict(let description):
            return LocalizationManager.shared.localizedString(description)
        }
    }
}

/// A before-and-after snapshot produced by `NodePatchEngine.preview`.
/// The UI presents this to the user before committing any change.
public struct NodePatchPreview: Hashable {
    /// The node that would be modified.
    public let nodeID: UUID
    /// The role of that node (e.g. `.miniApp`).
    public let role: NodeRole
    /// Which section of the Mini-App is being patched.
    public let section: CoCaptainNodeEditProposal.MiniAppSection
    /// The section text before any operations are applied.
    public let originalText: String
    /// The section text after all operations have been applied in order.
    public let resultText: String
}

/// Applies deterministic text operations proposed by CoCaptain to canonical
/// project nodes. It previews changes first so the UI can keep edits
/// human-approved and conflict-aware.
public struct NodePatchEngine {
    public init() {}

    /// Looks up the target node either by explicit UUID or by canonical role.
    ///
    /// - When `nodeID` is provided the node must be a Mini-App; any other type
    ///   returns `nil` to prevent accidental edits to incompatible node types.
    /// - When `nodeID` is absent the canvas is searched for the first node whose
    ///   role matches and is marked as an editable canonical role.
    @MainActor
    public func resolveNode(nodeID: UUID? = nil, for role: NodeRole, in store: ProjectStore) -> SpatialNode? {
        if let nodeID {
            guard let node = store.nodes.first(where: { $0.id == nodeID }),
                  node.type == .miniApp else {
                return nil
            }
            return node
        }
        guard role.isEditableCanonicalRole else { return nil }
        return store.nodes.first(where: { role.matches(node: $0) })
    }

    /// Computes the result of applying `operations` without persisting anything.
    ///
    /// - Parameters:
    ///   - nodeID: Optional UUID of a specific Mini-App node. Falls back to role-based lookup.
    ///   - role: The canonical role used when `nodeID` is `nil`.
    ///   - section: Which Mini-App section (`.srs` or `.code`) to patch.
    ///   - operations: The ordered list of operations to simulate.
    ///   - store: The active project whose nodes are searched.
    /// - Returns: A `NodePatchPreview` the UI can show for approval.
    /// - Throws: `NodePatchError` when the node cannot be found or an exact-match
    ///   operation fails to locate its target.
    @MainActor
    public func preview(
        nodeID: UUID? = nil,
        role: NodeRole,
        section: CoCaptainNodeEditProposal.MiniAppSection = .code,
        operations: [NodePatchOperation],
        in store: ProjectStore
    ) throws -> NodePatchPreview {
        guard let node = resolveNode(nodeID: nodeID, for: role, in: store) else {
            if let nodeID {
                throw NodePatchError.missingNodeID(nodeID)
            }
            throw NodePatchError.missingNode(role)
        }

        let originalText: String
        switch section {
        case .srs:
            originalText = node.miniApp?.srsText ?? ""
        case .code:
            originalText = node.miniApp?.codeText ?? ""
        }
        let resultText = try apply(operations: operations, to: originalText)
        return NodePatchPreview(nodeID: node.id, role: node.role, section: section, originalText: originalText, resultText: resultText)
    }

    /// Applies operations in order. Exact operations fail fast when their target
    /// text is missing, preventing model output from silently editing the wrong area.
    public func apply(operations: [NodePatchOperation], to text: String) throws -> String {
        var updatedText = text

        for operation in operations {
            switch operation.type {
            case .replaceAll:
                updatedText = operation.content
            case .replaceExact:
                guard let target = operation.target, let range = updatedText.range(of: target) else {
                    throw NodePatchError.conflict("Could not find exact text to replace.")
                }
                updatedText.replaceSubrange(range, with: operation.content)
            case .insertBeforeExact:
                guard let target = operation.target, let range = updatedText.range(of: target) else {
                    throw NodePatchError.conflict("Could not find exact text to insert before.")
                }
                updatedText.insert(contentsOf: operation.content, at: range.lowerBound)
            case .insertAfterExact:
                guard let target = operation.target, let range = updatedText.range(of: target) else {
                    throw NodePatchError.conflict("Could not find exact text to insert after.")
                }
                updatedText.insert(contentsOf: operation.content, at: range.upperBound)
            case .append:
                updatedText += operation.content
            case .prepend:
                updatedText = operation.content + updatedText
            }
        }

        return updatedText
    }
}
