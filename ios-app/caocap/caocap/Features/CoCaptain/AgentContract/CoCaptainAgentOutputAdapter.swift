import Foundation

/// Identifies which wire format the model used to deliver its structured
/// output in a given turn. Used for diagnostics and telemetry.
public enum CoCaptainAgentOutputSource: String, Hashable {
    /// The model wrapped actions in a `<cocaptain_actions>` XML block in text.
    case xml = "xml"
    /// The model used Gemini function-calling to invoke `request_app_action`.
    case functionCall = "function_call"
    /// The model delivered node edits or a clarifying question through the
    /// `propose_node_edit` / `ask_clarifying_question` tools.
    case nodeEditFunctionCall = "node_edit_function_call"
    /// Both mechanisms fired in the same turn and were merged.
    case combined = "combined"
}

/// The normalised, adapter-independent output of one model turn, ready for
/// the coordinator to validate and route into the review pipeline.
public struct CoCaptainAgentDirective: Hashable {
    /// The conversational text that precedes the structured action block.
    public let preamble: String
    /// The chat-visible text, equal to `preamble` for XML responses or the
    /// function-call visible text when no XML block is present.
    public let visibleText: String
    /// The decoded, actionable payload, or `nil` when the model produced no
    /// structured output for this turn.
    public let payload: CoCaptainAgentPayload?
    /// Validation or parsing errors discovered while processing the response.
    /// A non-empty array causes the coordinator to attempt an agentic retry.
    public let diagnostics: [String]
    /// Which adapter produced this directive.
    public let source: CoCaptainAgentOutputSource

    public init(
        preamble: String,
        visibleText: String,
        payload: CoCaptainAgentPayload?,
        diagnostics: [String] = [],
        source: CoCaptainAgentOutputSource
    ) {
        self.preamble = preamble
        self.visibleText = visibleText
        self.payload = payload
        self.diagnostics = diagnostics
        self.source = source
    }
}

/// Converts raw model output into a directive the coordinator can validate and
/// execute. Future Gemini function-call or structured-output adapters should
/// produce this same directive so orchestration stays independent of wire shape.
public protocol CoCaptainAgentOutputAdapting {
    /// Extracts the conversational visible text from a raw response string.
    /// - Parameter response: The raw text returned by the model.
    /// - Returns: The text content intended for display.
    func visibleText(from response: String) -> String
    /// Converts a raw response and optional function calls into a directive.
    /// - Parameters:
    ///   - response: The raw text returned by the model.
    ///   - functionCalls: A list of function calls triggered by the model.
    /// - Returns: A fully formed `CoCaptainAgentDirective`.
    func directive(from response: String, functionCalls: [CoCaptainAgentFunctionCall]) -> CoCaptainAgentDirective
}

public extension CoCaptainAgentOutputAdapting {
    /// Convenience overload for callers that have no function-call events,
    /// defaulting to an empty array so they don't need to pass it explicitly.
    func directive(from response: String) -> CoCaptainAgentDirective {
        directive(from: response, functionCalls: [])
    }
}

/// Adapter that decodes the `<cocaptain_actions>` XML fenced format.
///
/// Delegates all XML parsing to `CoCaptainAgentParser` and wraps the result
/// in a `CoCaptainAgentDirective`. Function calls are ignored by this adapter;
/// use `CoCaptainCompositeAgentAdapter` to handle both formats.
public struct CoCaptainXMLAgentAdapter: CoCaptainAgentOutputAdapting {
    private let parser: CoCaptainAgentParser

    public init(parser: CoCaptainAgentParser = CoCaptainAgentParser()) {
        self.parser = parser
    }

    public func visibleText(from response: String) -> String {
        parser.visibleText(from: response)
    }

    public func directive(from response: String, functionCalls: [CoCaptainAgentFunctionCall]) -> CoCaptainAgentDirective {
        let parsed = parser.parse(response)
        return CoCaptainAgentDirective(
            preamble: parsed.preamble,
            visibleText: parsed.visibleText,
            payload: parsed.payload,
            // Wrap single diagnostic in an array for uniform handling downstream.
            diagnostics: parsed.diagnostic.map { [$0] } ?? [],
            source: .xml
        )
    }
}

/// Adapter that converts Gemini native function-call events into a directive.
///
/// Only `request_app_action` calls are understood. Each call must carry an
/// `actionId` argument and an optional `executionMode` of `"safe"` or
/// `"pending"` (defaults to `"pending"` when absent).
public struct CoCaptainFunctionCallAgentAdapter {
    /// The Gemini tool name the model must invoke for app actions.
    public static let requestAppActionName = "request_app_action"

    public init() {}

    /// Converts an array of raw function-call events into a directive.
    ///
    /// Unknown function names and malformed arguments are collected as
    /// diagnostics rather than silently dropped, so the validator can
    /// feed them back to the model via an agentic retry.
    public func directive(
        from functionCalls: [CoCaptainAgentFunctionCall],
        visibleText: String = ""
    ) -> CoCaptainAgentDirective {
        var safeActions: [CoCaptainAgentAction] = []
        var pendingActions: [CoCaptainAgentAction] = []
        var diagnostics: [String] = []

        for functionCall in functionCalls {
            guard functionCall.name == Self.requestAppActionName else {
                diagnostics.append("Unknown function call `\(functionCall.name)`.")
                continue
            }

            guard let actionID = nonEmptyArgument("actionId", in: functionCall)
                ?? nonEmptyArgument("action_id", in: functionCall) else {
                diagnostics.append("Function call `\(functionCall.name)` is missing `actionId`.")
                continue
            }

            // Default to pending so unknown modes don't silently auto-execute.
            let executionMode = (nonEmptyArgument("executionMode", in: functionCall) ?? "pending")
                .lowercased()
            let action = CoCaptainAgentAction(
                actionID: actionID,
                args: supplementalArguments(from: functionCall)
            )

            switch executionMode {
            case "safe":
                safeActions.append(action)
            case "pending":
                pendingActions.append(action)
            default:
                diagnostics.append("Function call `\(functionCall.name)` has invalid `executionMode` `\(executionMode)`.")
            }
        }

        // Only build a payload when at least one valid action was decoded;
        // an empty payload is represented as nil so the coordinator knows
        // the model produced no executable intent.
        let payload = safeActions.isEmpty && pendingActions.isEmpty
            ? nil
            : CoCaptainAgentPayload(
                assistantMessage: visibleText,
                safeActions: safeActions,
                pendingActions: pendingActions,
                nodeEdits: []
            )

        return CoCaptainAgentDirective(
            preamble: visibleText,
            visibleText: visibleText,
            payload: payload,
            diagnostics: diagnostics,
            source: .functionCall
        )
    }

    /// Returns a trimmed, non-empty argument value, or `nil` if the key is
    /// absent or the value is blank after trimming whitespace.
    private func nonEmptyArgument(_ key: String, in functionCall: CoCaptainAgentFunctionCall) -> String? {
        functionCall.stringArgument(key)
    }

    private func supplementalArguments(from functionCall: CoCaptainAgentFunctionCall) -> [String: String]? {
        let reservedKeys = Set(["actionId", "action_id", "executionMode"])
        var args: [String: String] = [:]
        for (key, value) in functionCall.arguments where !reservedKeys.contains(key) {
            guard let scalar = value.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !scalar.isEmpty else {
                continue
            }
            args[key] = scalar
        }
        return args.isEmpty ? nil : args
    }
}

/// Adapter that converts `propose_node_edit` and `ask_clarifying_question`
/// function calls into the existing `CoCaptainAgentPayload` shapes.
///
/// The mapping is deliberately thin: the validator, verified coding loop,
/// review builder, and baseText conflict guard all consume the same
/// `CoCaptainNodeEditProposal` / `CoCaptainClarifyingQuestion` values they
/// receive from the XML parser, so downstream safety stays untouched.
public struct CoCaptainNodeEditFunctionAdapter {
    /// The tool names this adapter understands. The composite adapter uses
    /// this set to partition calls between adapters.
    public static let handledFunctionNames: Set<String> = [
        CoCaptainNodeEditTools.proposeNodeEditName,
        CoCaptainNodeEditTools.askClarifyingQuestionName
    ]

    public init() {}

    /// Converts node-edit tool calls into a directive. Malformed arguments
    /// become diagnostics so the agentic retry can feed them back to the model.
    public func directive(
        from functionCalls: [CoCaptainAgentFunctionCall],
        visibleText: String = ""
    ) -> CoCaptainAgentDirective {
        var nodeEdits: [CoCaptainNodeEditProposal] = []
        var clarifyingQuestion: CoCaptainClarifyingQuestion?
        var diagnostics: [String] = []

        for functionCall in functionCalls {
            switch functionCall.name {
            case CoCaptainNodeEditTools.proposeNodeEditName:
                switch nodeEdit(from: functionCall) {
                case .success(let edit):
                    nodeEdits.append(edit)
                case .failure(let issue):
                    diagnostics.append(issue)
                }
            case CoCaptainNodeEditTools.askClarifyingQuestionName:
                if let question = question(from: functionCall) {
                    // Keep the first well-formed question; the contract allows one.
                    clarifyingQuestion = clarifyingQuestion ?? question
                } else {
                    diagnostics.append(
                        "Function call `\(functionCall.name)` needs a non-empty `prompt` and \(CoCaptainClarifyingQuestion.minimumOptions)-\(CoCaptainClarifyingQuestion.maximumOptions) non-empty `options`."
                    )
                }
            default:
                diagnostics.append("Unknown function call `\(functionCall.name)`.")
            }
        }

        let payload = nodeEdits.isEmpty && clarifyingQuestion == nil
            ? nil
            : CoCaptainAgentPayload(
                assistantMessage: visibleText,
                nodeEdits: nodeEdits,
                clarifyingQuestion: clarifyingQuestion
            )

        return CoCaptainAgentDirective(
            preamble: visibleText,
            visibleText: visibleText,
            payload: payload,
            diagnostics: diagnostics,
            source: .nodeEditFunctionCall
        )
    }

    private enum NodeEditMappingResult {
        case success(CoCaptainNodeEditProposal)
        case failure(String)
    }

    private func nodeEdit(from functionCall: CoCaptainAgentFunctionCall) -> NodeEditMappingResult {
        guard let summary = functionCall.stringArgument("summary") else {
            return .failure("`propose_node_edit` requires a non-empty `summary`.")
        }
        guard let operationValues = functionCall.arguments["operations"]?.arrayValue,
              !operationValues.isEmpty else {
            return .failure("`propose_node_edit` requires a non-empty `operations` array.")
        }

        var operations: [NodePatchOperation] = []
        for value in operationValues {
            guard let object = value.objectValue,
                  let typeRaw = object["type"]?.stringValue,
                  let type = NodePatchOperationType(rawValue: typeRaw),
                  let content = object["content"]?.stringValue else {
                return .failure("`propose_node_edit` has a malformed operation; each needs a valid `type` and `content`.")
            }
            operations.append(
                NodePatchOperation(type: type, target: object["target"]?.stringValue, content: content)
            )
        }

        var verificationChecks: [CoCaptainVerificationCheck] = []
        if let checkValues = functionCall.arguments["verificationChecks"]?.arrayValue {
            for value in checkValues {
                guard let object = value.objectValue,
                      let id = object["id"]?.stringValue,
                      let description = object["description"]?.stringValue,
                      let script = object["script"]?.stringValue else {
                    return .failure("`propose_node_edit` has a malformed verification check; each needs `id`, `description`, and `script`.")
                }
                verificationChecks.append(
                    CoCaptainVerificationCheck(id: id, description: description, script: script)
                )
            }
        }

        let learningNote: CoCaptainLearningNote? = functionCall.arguments["learningNote"]?.objectValue.flatMap { object in
            guard let concept = object["concept"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let body = object["body"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !concept.isEmpty, !body.isEmpty else {
                // Malformed notes degrade to nil; they never invalidate the edit.
                return nil
            }
            return CoCaptainLearningNote(concept: concept, body: body)
        }

        let sectionName = functionCall.stringArgument("section")?.lowercased()
        let section = sectionName.flatMap(CoCaptainNodeEditProposal.MiniAppSection.init(rawValue:)) ?? .code
        let nodeID = (functionCall.stringArgument("nodeId") ?? functionCall.stringArgument("node_id"))
            .flatMap(UUID.init(uuidString:))

        return .success(
            CoCaptainNodeEditProposal(
                nodeID: nodeID,
                role: .miniApp,
                section: section,
                summary: summary,
                operations: operations,
                verificationChecks: verificationChecks,
                learningNote: learningNote
            )
        )
    }

    private func question(from functionCall: CoCaptainAgentFunctionCall) -> CoCaptainClarifyingQuestion? {
        guard let prompt = functionCall.stringArgument("prompt") else { return nil }
        let options = (functionCall.arguments["options"]?.arrayValue ?? [])
            .compactMap { $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard options.count >= CoCaptainClarifyingQuestion.minimumOptions else { return nil }
        return CoCaptainClarifyingQuestion(
            prompt: prompt,
            options: Array(options.prefix(CoCaptainClarifyingQuestion.maximumOptions))
        )
    }
}

/// Merges XML-fenced and Gemini function-call output into a single directive.
///
/// When the model produces both an XML block and native function calls in the
/// same turn, their actions are combined: function calls supply `safeActions`
/// and `pendingActions`; the XML block supplies `nodeEdits` and
/// `assistantMessage`. Diagnostics from both adapters are concatenated.
public struct CoCaptainCompositeAgentAdapter: CoCaptainAgentOutputAdapting {
    private let xmlAdapter: CoCaptainXMLAgentAdapter
    private let functionCallAdapter: CoCaptainFunctionCallAgentAdapter
    private let nodeEditAdapter: CoCaptainNodeEditFunctionAdapter

    public init(
        xmlAdapter: CoCaptainXMLAgentAdapter = CoCaptainXMLAgentAdapter(),
        functionCallAdapter: CoCaptainFunctionCallAgentAdapter = CoCaptainFunctionCallAgentAdapter(),
        nodeEditAdapter: CoCaptainNodeEditFunctionAdapter = CoCaptainNodeEditFunctionAdapter()
    ) {
        self.xmlAdapter = xmlAdapter
        self.functionCallAdapter = functionCallAdapter
        self.nodeEditAdapter = nodeEditAdapter
    }

    public func visibleText(from response: String) -> String {
        xmlAdapter.visibleText(from: response)
    }

    public func directive(from response: String, functionCalls: [CoCaptainAgentFunctionCall]) -> CoCaptainAgentDirective {
        let fencedDirective = xmlAdapter.directive(from: response, functionCalls: [])
        // If there are no function calls, return the XML directive directly to
        // avoid building a redundant combined payload.
        guard !functionCalls.isEmpty else { return fencedDirective }

        // Partition calls between the node-edit adapter and the app-action
        // adapter so neither flags the other's tools as unknown.
        let nodeEditCalls = functionCalls.filter {
            CoCaptainNodeEditFunctionAdapter.handledFunctionNames.contains($0.name)
        }
        let actionCalls = functionCalls.filter {
            !CoCaptainNodeEditFunctionAdapter.handledFunctionNames.contains($0.name)
        }

        let functionDirective = actionCalls.isEmpty
            ? nil
            : functionCallAdapter.directive(from: actionCalls, visibleText: fencedDirective.visibleText)
        let nodeEditDirective = nodeEditCalls.isEmpty
            ? nil
            : nodeEditAdapter.directive(from: nodeEditCalls, visibleText: fencedDirective.visibleText)

        let payload = combine(
            functionDirective?.payload,
            nodeEditDirective?.payload,
            fencedDirective.payload
        )
        return CoCaptainAgentDirective(
            preamble: fencedDirective.preamble,
            visibleText: fencedDirective.visibleText,
            payload: payload,
            diagnostics: (functionDirective?.diagnostics ?? [])
                + (nodeEditDirective?.diagnostics ?? [])
                + fencedDirective.diagnostics,
            source: mergedSource(
                hasActionPayload: functionDirective?.payload != nil,
                hasNodeEditPayload: nodeEditDirective?.payload != nil,
                hasFencedPayload: fencedDirective.payload != nil
            )
        )
    }

    /// Merges the three optional payload sources.
    ///
    /// - Safe/pending actions come from the `request_app_action` side.
    /// - Node edits and clarifying question prefer the function-call tools;
    ///   when the model emitted both tools and XML in the same turn, the
    ///   function-call edits win and the XML edits are dropped.
    /// - `assistantMessage` comes from the XML payload (richer prose) if
    ///   present; falls back to the function-call visible text.
    private func combine(
        _ functionPayload: CoCaptainAgentPayload?,
        _ nodeEditPayload: CoCaptainAgentPayload?,
        _ fencedPayload: CoCaptainAgentPayload?
    ) -> CoCaptainAgentPayload? {
        guard functionPayload != nil || nodeEditPayload != nil || fencedPayload != nil else {
            return nil
        }

        let nodeEdits = (nodeEditPayload?.nodeEdits.isEmpty == false)
            ? nodeEditPayload?.nodeEdits ?? []
            : fencedPayload?.nodeEdits ?? []

        return CoCaptainAgentPayload(
            assistantMessage: fencedPayload?.assistantMessage
                ?? nodeEditPayload?.assistantMessage
                ?? functionPayload?.assistantMessage
                ?? "",
            safeActions: functionPayload?.safeActions ?? [],
            pendingActions: functionPayload?.pendingActions ?? [],
            nodeEdits: nodeEdits,
            clarifyingQuestion: nodeEditPayload?.clarifyingQuestion ?? fencedPayload?.clarifyingQuestion
        )
    }

    private func mergedSource(
        hasActionPayload: Bool,
        hasNodeEditPayload: Bool,
        hasFencedPayload: Bool
    ) -> CoCaptainAgentOutputSource {
        let contributions = [hasActionPayload, hasNodeEditPayload, hasFencedPayload]
            .filter { $0 }
            .count
        if contributions > 1 { return .combined }
        if hasNodeEditPayload { return .nodeEditFunctionCall }
        if hasActionPayload { return .functionCall }
        return .xml
    }
}
