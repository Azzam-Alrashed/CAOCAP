import Foundation
import Testing
@testable import caocap

struct ChatBubbleMarkdownNormalizerTests {
    @Test func insertsBreakBeforeGluedSectionHeading() {
        let input =
            "End of first point about collaboration.Decoupled Logic Architecture: Implement this next."
        let output = ChatBubbleMarkdownNormalizer.normalizeAssistantText(input)
        #expect(output.contains("collaboration.\n\nDecoupled Logic Architecture:"))
    }

    @Test func insertsBreakBeforeMidTextNumberedItem() {
        let input = "First idea is done. 2. Second idea starts here."
        let output = ChatBubbleMarkdownNormalizer.normalizeAssistantText(input)
        #expect(output.contains("done.\n\n2. Second"))
    }

    @Test func leavesUserLikeTextUnchangedWhenAlreadyFormatted() {
        let input = "1. First\n\n2. Second"
        let output = ChatBubbleMarkdownNormalizer.normalizeAssistantText(input)
        #expect(output == input)
    }
}
