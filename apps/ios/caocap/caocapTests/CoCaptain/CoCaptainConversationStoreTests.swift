import Foundation
import Testing
@testable import caocap

struct CoCaptainConversationStoreTests {
    @Test func archiveRoundTripsTimelineAndReadingPosition() async throws {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let userMessage = ChatBubbleItem(
            text: "Review this canvas",
            isUser: true,
            turnMode: .agent,
            turnPurpose: .standard
        )
        let error = CoCaptainErrorItem(
            kind: .network,
            title: "Connection interrupted",
            message: "Your message is safe.",
            sourceMessageID: userMessage.id
        )
        let readingPosition = UUID()
        let conversation = CoCaptainConversation(
            title: "Canvas review",
            items: [
                CoCaptainTimelineItem(content: .message(userMessage)),
                CoCaptainTimelineItem(content: .error(error))
            ],
            lastScrollPosition: readingPosition
        )
        let archive = CoCaptainConversationArchive(
            activeConversationID: conversation.id,
            conversations: [conversation]
        )

        try await fixture.store.save(archive, for: "canvas_alpha.json")
        let loaded = try await fixture.store.loadArchive(for: "canvas_alpha.json")
        let restored = try #require(loaded)

        #expect(restored.schemaVersion == archive.schemaVersion)
        #expect(restored.activeConversationID == archive.activeConversationID)
        #expect(restored.conversations[0].title == conversation.title)
        #expect(
            restored.conversations[0].items.map(\.content)
                == conversation.items.map(\.content)
        )
        #expect(restored.conversations[0].lastScrollPosition == readingPosition)
    }

    @Test func archivesAreIsolatedByCanvasFileName() async throws {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let first = archive(title: "First canvas")
        let second = archive(title: "Second canvas")

        try await fixture.store.save(first, for: "canvas_one.json")
        try await fixture.store.save(second, for: "canvas_two.json")

        let loadedFirst = try await fixture.store.loadArchive(for: "canvas_one.json")
        let loadedSecond = try await fixture.store.loadArchive(for: "canvas_two.json")
        let restoredFirst = try #require(loadedFirst)
        let restoredSecond = try #require(loadedSecond)
        #expect(restoredFirst.conversations[0].title == "First canvas")
        #expect(restoredSecond.conversations[0].title == "Second canvas")
    }

    @Test func deleteRemovesOnlyTheRequestedArchive() async throws {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        try await fixture.store.save(archive(title: "Delete me"), for: "delete.json")
        try await fixture.store.save(archive(title: "Keep me"), for: "keep.json")

        await fixture.store.deleteArchive(for: "delete.json")

        let deleted = try await fixture.store.loadArchive(for: "delete.json")
        let kept = try await fixture.store.loadArchive(for: "keep.json")
        #expect(deleted == nil)
        #expect(kept != nil)
    }

    @Test func unsupportedSchemaIsRejected() async throws {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let unsupported = archive(title: "Future", schemaVersion: 99)
        try await fixture.store.save(unsupported, for: "future.json")

        do {
            _ = try await fixture.store.loadArchive(for: "future.json")
            Issue.record("Expected an unsupported schema error.")
        } catch let error as CoCaptainConversationStoreError {
            guard case .unsupportedSchema(let version) = error else {
                Issue.record("Unexpected conversation store error.")
                return
            }
            #expect(version == 99)
        }
    }

    private func makeFixture() -> (root: URL, store: CoCaptainConversationStore) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "CoCaptainConversationStoreTests-\(UUID().uuidString)",
                isDirectory: true
            )
        return (root, CoCaptainConversationStore(baseDirectory: root))
    }

    private func archive(
        title: String,
        schemaVersion: Int = CoCaptainConversationArchive.currentSchemaVersion
    ) -> CoCaptainConversationArchive {
        let conversation = CoCaptainConversation(
            title: title,
            items: [
                CoCaptainTimelineItem(
                    content: .message(
                        ChatBubbleItem(text: title, isUser: true)
                    )
                )
            ]
        )
        return CoCaptainConversationArchive(
            schemaVersion: schemaVersion,
            activeConversationID: conversation.id,
            conversations: [conversation]
        )
    }
}
