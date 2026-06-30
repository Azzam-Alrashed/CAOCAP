import Testing
@testable import caocap

struct CoCaptainTurnIntentResolverTests {
  private let resolver = CoCaptainTurnIntentResolver()

  @Test func suggestImprovementsResolvesToAdvisory() {
    #expect(
      resolver.resolve("Suggest three useful next improvements for this project")
        == .advisory
    )
  }

  @Test func improveTheHeadingResolvesToMutatingWork() {
    #expect(resolver.resolve("improve the heading color") == .mutatingWork)
  }

  @Test func buildGameResolvesToMutatingWork() {
    #expect(resolver.resolve("build a Pac-Man game") == .mutatingWork)
  }

  @Test func casualStatementResolvesToGeneralChat() {
    #expect(resolver.resolve("I am connected to the internet") == .generalChat)
  }

  @Test func negatedUpdateResolvesToAdvisory() {
    #expect(resolver.resolve("don't update the code") == .advisory)
  }

  @Test func waysToImproveResolvesToAdvisory() {
    #expect(resolver.resolve("what are some ways to improve this layout") == .advisory)
  }

  @Test func mutatingWorkRequiresDegradedConnectionNotice() {
    #expect(CoCaptainTurnIntent.mutatingWork.requiresDegradedConnectionNotice)
    #expect(!CoCaptainTurnIntent.advisory.requiresDegradedConnectionNotice)
    #expect(!CoCaptainTurnIntent.generalChat.requiresDegradedConnectionNotice)
  }
}
