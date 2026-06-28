import Foundation

/// The outcome of a payload validation pass.
public struct CoCaptainAgentValidationResult: Hashable {
    /// A list of descriptive errors explaining why the payload cannot be safely executed.
    public let issues: [String]

    /// `true` if the payload has no structural or semantic errors.
    public var isValid: Bool {
        issues.isEmpty
    }
}

/// Validates model-produced agent payloads before any app action can execute.
/// The dispatcher remains the final execution boundary; this layer gives the
/// model deterministic feedback when it emits an unsafe or unusable contract.
public struct CoCaptainAgentValidator {
    public init() {}

    /// Validates the extracted model payload against the live capabilities of the application.
    /// Ensures requested actions exist and node edits have the correct structure.
    @MainActor
    public func validate(
        payload: CoCaptainAgentPayload,
        dispatcher: (any AppActionPerforming)?,
        requiresAgenticWork: Bool,
        requiresVerificationChecks: Bool = false
    ) -> CoCaptainAgentValidationResult {
        var issues: [String] = []

        for action in payload.safeActions {
            guard let id = AppActionID(rawValue: action.actionID) else {
                issues.append("Unknown safe action id `\(action.actionID)`.")
                continue
            }

            guard let definition = dispatcher?.definition(for: id) else {
                issues.append("Safe action `\(id.rawValue)` is not currently available.")
                continue
            }

            if !definition.allowsAutonomousExecution {
                issues.append("Safe action `\(id.rawValue)` is not autonomous; move it to `pendingActions`.")
            }
        }

        for action in payload.pendingActions {
            guard let id = AppActionID(rawValue: action.actionID) else {
                issues.append("Unknown pending action id `\(action.actionID)`.")
                continue
            }

            if dispatcher?.definition(for: id) == nil {
                issues.append("Pending action `\(id.rawValue)` is not currently available.")
            }
        }

        for edit in payload.nodeEdits {
            if edit.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("Node edit for `\(edit.role.rawValue)` needs a non-empty summary.")
            }

            if edit.operations.isEmpty {
                issues.append("Node edit for `\(edit.role.rawValue)` must include at least one operation.")
            }

            for operation in edit.operations {
                validate(operation: operation, role: edit.role, issues: &issues)
            }

            if requiresVerificationChecks, edit.section == .code {
                validate(verificationChecks: edit.verificationChecks, issues: &issues)
            }
        }

        if requiresAgenticWork,
           payload.safeActions.isEmpty,
           payload.pendingActions.isEmpty,
           payload.nodeEdits.isEmpty {
            issues.append("Build/edit requests must include at least one safe action, pending action, or node edit.")
        }

        return CoCaptainAgentValidationResult(issues: issues)
    }

    private func validate(
        verificationChecks: [CoCaptainVerificationCheck],
        issues: inout [String]
    ) {
        if verificationChecks.isEmpty {
            issues.append("Verified code edits require at least one verification check.")
            return
        }

        if verificationChecks.count > CoCaptainVerificationCheck.maximumCount {
            issues.append("Verified code edits may include at most \(CoCaptainVerificationCheck.maximumCount) checks.")
        }

        var ids = Set<String>()
        var totalScriptCharacters = 0
        for check in verificationChecks {
            let id = check.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = check.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let script = check.script.trimmingCharacters(in: .whitespacesAndNewlines)

            if id.isEmpty {
                issues.append("Verification checks require a non-empty id.")
            } else if !ids.insert(id).inserted {
                issues.append("Verification check id `\(id)` is duplicated.")
            }
            if description.isEmpty {
                issues.append("Verification check `\(id)` requires a description.")
            }
            if script.isEmpty {
                issues.append("Verification check `\(id)` requires a script.")
            }
            if script.count > CoCaptainVerificationCheck.maximumScriptCharacters {
                issues.append("Verification check `\(id)` exceeds the per-check script limit.")
            }
            if script.contains("]]>") {
                issues.append("Verification check `\(id)` contains an unsupported CDATA terminator.")
            }
            totalScriptCharacters += script.count
        }

        if totalScriptCharacters > CoCaptainVerificationCheck.maximumTotalScriptCharacters {
            issues.append("Verification checks exceed the total script limit.")
        }
    }

    /// Validates an individual patch operation to ensure it meets constraints for its type.
    private func validate(
        operation: NodePatchOperation,
        role: NodeRole,
        issues: inout [String]
    ) {
        if operation.content.isEmpty {
            issues.append("Node edit for `\(role.rawValue)` has an operation with empty content.")
        }

        switch operation.type {
        case .replaceExact, .insertBeforeExact, .insertAfterExact:
            if operation.target?.isEmpty != false {
                issues.append("Operation `\(operation.type.rawValue)` for `\(role.rawValue)` requires a non-empty target.")
            }
        case .replaceAll, .append, .prepend:
            break
        }
    }
}
