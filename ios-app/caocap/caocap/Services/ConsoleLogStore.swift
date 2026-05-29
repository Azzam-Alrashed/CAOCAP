import Foundation
import Observation

public struct ConsoleLogEntry: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let type: String // "log", "error", "warn", "info"
    public let message: String
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), type: String, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.message = message
    }
}

@Observable
@MainActor
public final class ConsoleLogStore {
    public static let shared = ConsoleLogStore()
    
    public var logs: [ConsoleLogEntry] = []
    
    private init() {}
    
    public func addLog(type: String, message: String) {
        let entry = ConsoleLogEntry(type: type, message: message)
        if logs.count >= 500 {
            logs.removeFirst()
        }
        logs.append(entry)
    }
    
    public func clear() {
        logs.removeAll()
    }
}
