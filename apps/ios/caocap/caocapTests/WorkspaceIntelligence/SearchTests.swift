import Foundation
import Testing
import CoreGraphics
@testable import caocap

struct SearchTests {

    @Test func searchIndexScoresTitleMatchesHigherThanSubtitle() throws {
        let nodes = [
            SpatialNode(id: UUID(), type: .standard, position: .zero, title: "Login Page", subtitle: "Form"),
            SpatialNode(id: UUID(), type: .standard, position: .zero, title: "Other", subtitle: "This contains the word login")
        ]
        let index = NodeSearchIndex()
        let results = index.search(query: "login", in: nodes)

        #expect(results.count == 2)
        #expect(results[0].title == "Login Page")
        #expect(results[0].relevanceScore > results[1].relevanceScore)
    }

    @Test func searchIndexMatchesCardTitle() throws {
        let previewNode = SpatialNode(id: UUID(), type: .standard, position: .zero, title: "Card")
        let index = NodeSearchIndex()
        let results = index.search(query: "card", in: [previewNode])

        #expect(results.count == 1)
        #expect(results[0].title == "Card")
    }

    @Test func viewportFlyToCalculatesCorrectOffset() throws {
        let viewport = ViewportState()
        let nodePosition = CGPoint(x: 100, y: 200)
        let containerSize = CGSize(width: 500, height: 800)

        viewport.flyTo(nodePosition: nodePosition, containerSize: containerSize, targetScale: 1.0)

        #expect(viewport.offset.width == -100)
        #expect(viewport.offset.height == -200)
        #expect(viewport.scale == 1.0)
    }

    @Test func viewportFlyToCalculatesCorrectOffsetWithFocusZoom() throws {
        let viewport = ViewportState()
        let nodePosition = CGPoint(x: 150, y: 300)
        let containerSize = CGSize(width: 600, height: 900)

        let nodeSize = CGSize(width: 300, height: 200)
        let paddingFactor: CGFloat = 0.8
        let scaleX = (containerSize.width * paddingFactor) / nodeSize.width
        let scaleY = (containerSize.height * paddingFactor) / nodeSize.height
        let targetScale = min(min(scaleX, scaleY), 1.2)

        #expect(targetScale == 1.2)

        viewport.flyTo(nodePosition: nodePosition, containerSize: containerSize, targetScale: targetScale)

        #expect(viewport.offset.width == -150 * 1.2)
        #expect(viewport.offset.height == -300 * 1.2)
        #expect(viewport.scale == 1.2)
    }

    @Test func viewportFitToCalculatesCorrectBoundsAndOffset() throws {
        let viewport = ViewportState()
        let nodes = [
            SpatialNode(id: UUID(), type: .standard, position: CGPoint(x: 100, y: 100), title: "Node 1"),
            SpatialNode(id: UUID(), type: .standard, position: CGPoint(x: 500, y: 400), title: "Node 2")
        ]

        let containerSize = CGSize(width: 800, height: 600)
        let padding: CGFloat = 100

        viewport.fitTo(nodes: nodes, containerSize: containerSize, padding: padding)

        #expect(viewport.scale == 1.2)
        #expect(viewport.offset.width == -360)
        #expect(viewport.offset.height == -300)
    }
}
