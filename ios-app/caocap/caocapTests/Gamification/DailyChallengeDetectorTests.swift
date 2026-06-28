import Foundation
import Testing
@testable import caocap

struct DailyChallengeDetectorTests {
  @Test func defaultHelloWorldHTMLMatchesNoChallenges() {
    let html = ProjectTemplateProvider.defaultCode
    #expect(DailyChallengeDetector.matchedChallengeIDs(in: html).isEmpty)
  }

  @Test func changedTitleMatchesIronChallenge() {
    var html = ProjectTemplateProvider.defaultCode
    html = html.replacingOccurrences(of: "<title>My App</title>", with: "<title>Studio App</title>")
    #expect(DailyChallengeDetector.matchesTitleChanged(html))
    #expect(DailyChallengeDetector.matchedChallengeIDs(in: html).contains("update_title"))
  }

  @Test func changedBackgroundMatchesGoldChallenge() {
    var html = ProjectTemplateProvider.defaultCode
    html = html.replacingOccurrences(of: "background-color: #0d0d0d;", with: "background-color: #112233;")
    #expect(DailyChallengeDetector.matchesBackgroundChanged(html))
  }

  @Test func imageTagMatchesDiamondChallenge() {
    let html = ProjectTemplateProvider.defaultCode + #"<img src="https://example.com/icon.png" alt="icon">"#
    #expect(DailyChallengeDetector.matchesImageAdded(html))
    #expect(DailyChallengeDetector.matchedChallengeIDs(in: html).contains("add_image"))
  }
}
