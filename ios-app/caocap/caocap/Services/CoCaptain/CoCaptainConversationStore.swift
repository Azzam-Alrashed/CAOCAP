import Foundation
import OSLog

/// One locally-persisted project-scoped CoCaptain conversation.
///
/// Node-scoped conversations continue to live in `NodeAgentState`; this model is
/// intentionally reserved for the project-wide CoCaptain surface.
public struct CoCaptainConversation: Identifiable, Codable, Hashable, @unchecked Sendable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var updatedAt: Date
    public var items: [CoCaptainTimelineItem]
    public var lastScrollPosition: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        items: [CoCaptainTimelineItem],
        lastScrollPosition: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
        self.lastScrollPosition = lastScrollPosition
    }
}

/// Versioned sidecar containing all project conversations for one canvas file.
public struct CoCaptainConversationArchive: Codable, Hashable, @unchecked Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public var activeConversationID: UUID
    public var conversations: [CoCaptainConversation]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        activeConversationID: UUID,
        conversations: [CoCaptainConversation]
    ) {
        self.schemaVersion = schemaVersion
        self.activeConversationID = activeConversationID
        self.conversations = conversations
    }
}

public enum CoCaptainConversationStoreError: LocalizedError {
    case unsupportedSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "CoCaptain conversation schema \(version) is not supported."
        }
    }
}

/// Local-first persistence for project-scoped CoCaptain conversations.
///
/// Conversation data is stored beside project files in a dedicated sidecar
/// directory. Keeping it outside `ProjectSnapshot` avoids a project schema bump
/// and prevents large attachments from slowing ordinary canvas saves.
public actor CoCaptainConversationStore {
    private let baseDirectory: URL
    private let fileManager: FileManager
    private let logger = Logger(
        subsystem: "com.caocap.app",
        category: "CoCaptainConversations"
    )

    public init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let appSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.baseDirectory = appSupport
                .appendingPathComponent("com.ficruty.caocap", isDirectory: true)
                .appendingPathComponent("cocaptain-conversations", isDirectory: true)
        }
    }

    public func loadArchive(for projectFileName: String) throws -> CoCaptainConversationArchive? {
        let url = archiveURL(for: projectFileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(CoCaptainConversationArchive.self, from: data)
        guard archive.schemaVersion == CoCaptainConversationArchive.currentSchemaVersion else {
            throw CoCaptainConversationStoreError.unsupportedSchema(archive.schemaVersion)
        }
        return archive
    }

    public func save(
        _ archive: CoCaptainConversationArchive,
        for projectFileName: String
    ) throws {
        try fileManager.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )

        let destination = archiveURL(for: projectFileName)
        let temporary = destination.appendingPathExtension("\(UUID().uuidString).tmp")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(archive)
        try data.write(to: temporary, options: .atomic)
        defer { try? fileManager.removeItem(at: temporary) }

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }

    public func deleteArchive(for projectFileName: String) {
        let url = archiveURL(for: projectFileName)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            logger.error(
                "Could not delete CoCaptain conversations: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func archiveURL(for projectFileName: String) -> URL {
        baseDirectory
            .appendingPathComponent(safeFileStem(projectFileName))
            .appendingPathExtension("json")
    }

    private func safeFileStem(_ fileName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitizedScalars = fileName.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(String(scalar)) : "_"
        }
        let value = String(sanitizedScalars)
        return value.isEmpty ? "canvas" : value
    }
}
