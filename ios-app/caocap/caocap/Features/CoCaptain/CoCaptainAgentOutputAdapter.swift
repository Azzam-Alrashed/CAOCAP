import Foundation

public enum CoCaptainAgentOutputSource: String, Hashable {
    case fencedJSON = "fenced_json"
}

public struct CoCaptainAgentDirective: Hashable {
    public let visibleText: String
    public let payload: CoCaptainAgentPayload?
    public let diagnostics: [String]
    public let source: CoCaptainAgentOutputSource

    public init(
        visibleText: String,
        payload: CoCaptainAgentPayload?,
        diagnostics: [String] = [],
        source: CoCaptainAgentOutputSource
    ) {
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
    func visibleText(from response: String) -> String
    func directive(from response: String) -> CoCaptainAgentDirective
}

public struct CoCaptainFencedJSONAgentAdapter: CoCaptainAgentOutputAdapting {
    private let parser: CoCaptainAgentParser

    public init(parser: CoCaptainAgentParser = CoCaptainAgentParser()) {
        self.parser = parser
    }

    public func visibleText(from response: String) -> String {
        parser.visibleText(from: response)
    }

    public func directive(from response: String) -> CoCaptainAgentDirective {
        let parsed = parser.parse(response)
        return CoCaptainAgentDirective(
            visibleText: parsed.visibleText,
            payload: parsed.payload,
            diagnostics: parsed.diagnostic.map { [$0] } ?? [],
            source: .fencedJSON
        )
    }
}
