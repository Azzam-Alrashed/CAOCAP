import Foundation

/// Splits model responses into user-visible text and an optional trailing
/// `cocaptain_actions` XML payload.
public struct CoCaptainAgentParser {
    private static let startTag = "<cocaptain_actions>"
    private static let endTag = "</cocaptain_actions>"

    public init() {}

    /// Parses the structured XML block in the response.
    public func parse(_ response: String) -> CoCaptainParsedResponse {
        guard let startRange = response.range(of: Self.startTag, options: .backwards),
              let endRange = response.range(of: Self.endTag, options: .backwards),
              startRange.lowerBound < endRange.lowerBound else {
            if let startRange = response.range(of: Self.startTag) {
                return CoCaptainParsedResponse(
                    preamble: String(response[..<startRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines),
                    payload: nil
                )
            }
            return CoCaptainParsedResponse(
                preamble: response.trimmingCharacters(in: .whitespacesAndNewlines),
                payload: nil
            )
        }

        let preamble = String(response[..<startRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let xmlRange = startRange.lowerBound..<endRange.upperBound
        let xml = String(response[xmlRange])

        let assistantMessage = extractTag(name: "assistant_message", from: xml) ?? ""
        
        let safeActions = extractTags(name: "safe_actions", from: xml).flatMap { 
            extractSelfClosingTags(name: "action", from: $0) 
        }.compactMap { attrs -> CoCaptainAgentAction? in
            guard let id = attrs["id"] else { return nil }
            return CoCaptainAgentAction(actionID: id)
        }
        
        let pendingActions = extractTags(name: "pending_actions", from: xml).flatMap { 
            extractSelfClosingTags(name: "action", from: $0) 
        }.compactMap { attrs -> CoCaptainAgentAction? in
            guard let id = attrs["id"] else { return nil }
            return CoCaptainAgentAction(actionID: id)
        }
        
        let nodeEdits = extractTagMatches(name: "node_edit", from: xml).compactMap { item -> CoCaptainNodeEditProposal? in
            let content = item.content
            let attrs = item.attributes
            let roleStr = attrs["role"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let role = roleStr.flatMap(NodeRole.init(rawValue:)) ?? .miniApp
            let sectionStr = attrs["section"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let section = sectionStr.flatMap(CoCaptainNodeEditProposal.MiniAppSection.init(rawValue:)) ?? .code
            let nodeID = (attrs["nodeId"] ?? attrs["node_id"] ?? attrs["nodeID"]).flatMap(UUID.init(uuidString:))
            
            let summary = attrs["summary"] ?? ""
            let operations = extractTagMatches(name: "operation", from: content).compactMap { opItem -> NodePatchOperation? in
                let opContent = opItem.content
                let opAttrs = opItem.attributes
                guard let typeStr = opAttrs["type"],
                      let type = NodePatchOperationType(rawValue: typeStr) else { return nil }
                
                let target = extractTag(name: "target", from: opContent)
                let body = extractCDATA(from: opContent) ?? extractTag(name: "content", from: opContent) ?? ""
                
                return NodePatchOperation(type: type, target: target, content: body)
            }
            
            return CoCaptainNodeEditProposal(nodeID: nodeID, role: role, section: section, summary: summary, operations: operations)
        }

        let payload = CoCaptainAgentPayload(
            assistantMessage: assistantMessage,
            safeActions: safeActions,
            pendingActions: pendingActions,
            nodeEdits: nodeEdits
        )

        return CoCaptainParsedResponse(preamble: preamble, payload: payload)
    }

    /// Returns the text that is safe to stream into the chat bubble.
    public func visibleText(from response: String) -> String {
        if let range = response.range(of: Self.startTag) {
            return response[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - XML Extraction Helpers

    /// Extracts the inner content of the first matching XML tag.
    /// - Parameters:
    ///   - name: The name of the XML tag to find.
    ///   - text: The raw text containing XML.
    /// - Returns: The trimmed inner content, or `nil` if the tag is not found.
    private func extractTag(name: String, from text: String) -> String? {
        let pattern = "<\(name)>(.*?)</\(name)>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex?.firstMatch(in: text, options: [], range: nsRange) {
            if let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    /// Represents a matched XML tag including its inner content and parsed attributes.
    private struct TagMatch {
        /// The inner text content of the tag.
        let content: String
        /// Dictionary of all key-value attributes parsed from the opening tag.
        let attributes: [String: String]
    }

    /// Extracts the inner content of all occurrences of a specified XML tag.
    /// - Returns: An array of trimmed strings for every matching tag.
    private func extractTags(name: String, from text: String) -> [String] {
        let pattern = "<\(name)[^>]*>(.*?)</\(name)>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex?.matches(in: text, options: [], range: nsRange) ?? []
        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }
    }

    /// Extracts all occurrences of a specified XML tag, parsing both attributes and inner content.
    /// - Returns: An array of `TagMatch` objects containing the parsed data.
    private func extractTagMatches(name: String, from text: String) -> [TagMatch] {
        let pattern = "<\(name)([^>]*)>(.*?)</\(name)>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex?.matches(in: text, options: [], range: nsRange) ?? []
        return matches.compactMap { match in
            guard let attrRange = Range(match.range(at: 1), in: text),
                  let contentRange = Range(match.range(at: 2), in: text) else { return nil }
            
            let attrString = String(text[attrRange])
            let content = String(text[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let attributes = parseAttributes(attrString)
            
            return TagMatch(content: content, attributes: attributes)
        }
    }

    /// Extracts the attributes from all self-closing occurrences of a specified XML tag.
    /// - Returns: An array of attribute dictionaries for each matching tag.
    private func extractSelfClosingTags(name: String, from text: String) -> [[String: String]] {
        let pattern = "<\(name)\\s+([^>]*?)/>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex?.matches(in: text, options: [], range: nsRange) ?? []
        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: text) {
                return parseAttributes(String(text[range]))
            }
            return nil
        }
    }

    /// Parses raw attribute strings (e.g. `key="value" key='value' key=value`) into a dictionary.
    private func parseAttributes(_ attrString: String) -> [String: String] {
        var attributes: [String: String] = [:]
        // Robust attribute parsing: handles key="val", key='val', or key=val (unquoted)
        // and allows optional whitespace around the equals sign.
        let pattern = "(\\w+)\\s*=\\s*(?:[\"']([^\"']*)[\"']|([^\\s>]+))"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsRange = NSRange(attrString.startIndex..<attrString.endIndex, in: attrString)
        let matches = regex?.matches(in: attrString, options: [], range: nsRange) ?? []
        for match in matches {
            if let keyRange = Range(match.range(at: 1), in: attrString) {
                let key = String(attrString[keyRange])
                if let valRange = Range(match.range(at: 2), in: attrString) {
                    attributes[key] = String(attrString[valRange])
                } else if let valRange = Range(match.range(at: 3), in: attrString) {
                    attributes[key] = String(attrString[valRange])
                }
            }
        }
        return attributes
    }

    /// Extracts the raw text from the first `<![CDATA[...]]>` section in the string.
    private func extractCDATA(from text: String) -> String? {
        let pattern = "<!\\[CDATA\\[(.*?)\\]\\]>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex?.firstMatch(in: text, options: [], range: nsRange) {
            if let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        return nil
    }
}
