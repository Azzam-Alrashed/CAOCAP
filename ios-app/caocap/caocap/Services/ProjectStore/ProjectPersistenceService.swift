import Foundation

public struct ProjectSnapshot: Codable, Equatable {
    public let schemaVersion: Int
    public let projectName: String?
    public let nodes: [SpatialNode]
    public let viewportOffset: CGSize
    public let viewportScale: CGFloat
    public var checkpointLabel: String?

    public init(
        schemaVersion: Int = ProjectPersistenceService.currentSchemaVersion,
        projectName: String?,
        nodes: [SpatialNode],
        viewportOffset: CGSize,
        viewportScale: CGFloat,
        checkpointLabel: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.projectName = projectName
        self.nodes = nodes
        self.viewportOffset = viewportOffset
        self.viewportScale = viewportScale
        self.checkpointLabel = checkpointLabel
    }
}

public struct SnapshotMetadata: Codable, Equatable, Identifiable {
    public let id: UUID
    public let date: Date
    public let label: String
    public let fileName: String

    public init(id: UUID = UUID(), date: Date = Date(), label: String, fileName: String) {
        self.id = id
        self.date = date
        self.label = label
        self.fileName = fileName
    }
}

public enum ProjectPersistenceError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(Int?, current: Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version, let current):
            if let version {
                return "Project schema version \(version) is not supported. Expected version \(current)."
            }
            return "Project is missing schema version. Expected version \(current)."
        }
    }
}

/// Encapsulates project file layout, schema decoding, and atomic JSON writes so
/// ProjectStore can stay focused on observable project state.
public struct ProjectPersistenceService: Sendable {
    public static let currentSchemaVersion = 3

    private struct VersionCheck: Codable {
        let schemaVersion: Int?
    }

    private let baseDirectory: URL?

    public init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory
    }

    public func workspaceDirectory() -> URL {
        projectDirectory()
    }

    public func fileURL(for fileName: String) -> URL {
        projectDirectory().appendingPathComponent(fileName)
    }

    public func projectExists(fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: fileName).path)
    }

    public func load(fileName: String) throws -> ProjectSnapshot {
        let data = try Data(contentsOf: fileURL(for: fileName))
        let decoder = JSONDecoder()
        let versionCheck = try? decoder.decode(VersionCheck.self, from: data)
        try requireCurrentSchema(versionCheck?.schemaVersion)
        return try decoder.decode(ProjectSnapshot.self, from: data)
    }

    public func save(_ snapshot: ProjectSnapshot, fileName: String) throws {
        let url = fileURL(for: fileName)
        let tempURL = url.appendingPathExtension("\(UUID().uuidString).tmp")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(snapshot)

        try data.write(to: tempURL)

        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: url)
        }

        try? FileManager.default.removeItem(at: tempURL)
    }

    public func saveSnapshot(_ snapshot: ProjectSnapshot, fileName: String, label: String) throws -> SnapshotMetadata {
        let id = UUID()
        let snapshotFileName = "\(id.uuidString).json"
        let directory = snapshotsDirectory(for: fileName)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        var mutableSnapshot = snapshot
        mutableSnapshot.checkpointLabel = label
        
        let url = directory.appendingPathComponent(snapshotFileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(mutableSnapshot)
        try data.write(to: url)
        
        return SnapshotMetadata(id: id, date: Date(), label: label, fileName: snapshotFileName)
    }

    public func loadSnapshot(metadata: SnapshotMetadata, for projectFileName: String) throws -> ProjectSnapshot {
        let url = snapshotsDirectory(for: projectFileName)
            .appendingPathComponent(metadata.fileName)
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let versionCheck = try? decoder.decode(VersionCheck.self, from: data)
        try requireCurrentSchema(versionCheck?.schemaVersion)
        return try decoder.decode(ProjectSnapshot.self, from: data)
    }

    public func deleteSnapshot(metadata: SnapshotMetadata, for projectFileName: String) throws {
        let url = snapshotsDirectory(for: projectFileName)
            .appendingPathComponent(metadata.fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    public func listSnapshots(for fileName: String) -> [SnapshotMetadata] {
        let directory = snapshotsDirectory(for: fileName)
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else {
            return []
        }
        
        let decoder = JSONDecoder()
        return files.compactMap { url in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let versionCheck = try? decoder.decode(VersionCheck.self, from: data),
                  versionCheck.schemaVersion == Self.currentSchemaVersion,
                  let snapshot = try? decoder.decode(ProjectSnapshot.self, from: data),
                  let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let date = attributes[.creationDate] as? Date else {
                return nil
            }
            
            return SnapshotMetadata(
                id: UUID(uuidString: url.deletingPathExtension().lastPathComponent) ?? UUID(),
                date: date,
                label: snapshot.checkpointLabel ?? "Manual Checkpoint",
                fileName: url.lastPathComponent
            )
        }.sorted { $0.date > $1.date }
    }

    public func snapshotsDirectory(for fileName: String) -> URL {
        projectDirectory()
            .appendingPathComponent("snapshots")
            .appendingPathComponent(fileName.replacingOccurrences(of: ".json", with: ""))
    }

    private func projectDirectory() -> URL {
        if let baseDirectory {
            try? FileManager.default.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true
            )
            return baseDirectory
        }

        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("com.ficruty.caocap", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport
    }

    private func requireCurrentSchema(_ version: Int?) throws {
        guard version == Self.currentSchemaVersion else {
            throw ProjectPersistenceError.unsupportedSchemaVersion(version, current: Self.currentSchemaVersion)
        }
    }
}

public actor ProjectPersistenceWriter {
    private let persistence: ProjectPersistenceService

    public init(persistence: ProjectPersistenceService = ProjectPersistenceService()) {
        self.persistence = persistence
    }

    public func save(_ snapshot: ProjectSnapshot, fileName: String) throws {
        try persistence.save(snapshot, fileName: fileName)
    }
}
