//
//  caocapTests.swift
//  caocapTests
//
//  Created by الشيخ عزام on 20/04/2026.
//

import CoreGraphics
import Testing
@testable import caocap

struct caocapTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func viewportDragTranslationUsesPhysicalDirections() {
        let viewport = ViewportState(offset: CGSize(width: 10, height: -20), scale: 1.0)

        viewport.handleDragTranslation(CGSize(width: 35, height: -15))
        #expect(viewport.offset == CGSize(width: 45, height: -35))

        viewport.handleDragEnded()
        viewport.handleDragTranslation(CGSize(width: -25, height: 40))
        #expect(viewport.offset == CGSize(width: 20, height: 5))
    }

    @Test func viewportDragEndedCommitsOffsetForNextGesture() {
        let viewport = ViewportState(offset: .zero, scale: 1.0)

        viewport.handleDragTranslation(CGSize(width: 50, height: 12))
        viewport.handleDragEnded()
        viewport.handleDragTranslation(CGSize(width: 10, height: -2))

        #expect(viewport.offset == CGSize(width: 60, height: 10))
        #expect(viewport.lastOffset == CGSize(width: 50, height: 12))
    }
}
