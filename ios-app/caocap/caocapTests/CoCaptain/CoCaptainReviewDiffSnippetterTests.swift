import Testing
@testable import caocap

struct CoCaptainReviewDiffSnippetterTests {
    @Test func focusesWindowAroundSingleLineChange() {
        let before = (1...20).map { "line \($0)" }.joined(separator: "\n")
        let afterLines = (1...20).map { $0 == 10 ? "line 10 changed" : "line \($0)" }
        let after = afterLines.joined(separator: "\n")

        let snippets = CoCaptainReviewDiffSnippetter.makeSnippets(before: before, after: after)

        #expect(snippets.before.contains("line 10"))
        #expect(snippets.after.contains("line 10 changed"))
        #expect(snippets.before.contains("…") || snippets.after.contains("…"))
        #expect(!snippets.before.contains("line 1\nline 2\nline 3\nline 4\nline 5\nline 6"))
    }

    @Test func truncatesVeryLongUnchangedDocuments() {
        let huge = String(repeating: "a", count: 2_000)
        let snippets = CoCaptainReviewDiffSnippetter.makeSnippets(before: huge, after: huge)
        #expect(snippets.before.contains("[TRUNCATED]"))
        #expect(snippets.before.count <= CoCaptainReviewDiffSnippetter.maximumSnippetCharacters + 20)
    }

    @Test func emptyInputsStayEmpty() {
        let snippets = CoCaptainReviewDiffSnippetter.makeSnippets(before: "", after: "hello")
        #expect(snippets.before.isEmpty)
        #expect(snippets.after == "hello")
    }
}
