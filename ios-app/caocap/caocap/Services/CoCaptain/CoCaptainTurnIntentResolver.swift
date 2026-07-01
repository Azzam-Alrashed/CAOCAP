import Foundation

/// Resolves a user message into a `CoCaptainTurnIntent` using conservative
/// phrase matching shared with `CommandIntentResolver`.
public struct CoCaptainTurnIntentResolver {
    public init() {}

    public func resolve(_ userMessage: String) -> CoCaptainTurnIntent {
        let normalized = CommandIntentResolver.normalizedCommandInput(userMessage)
        guard !normalized.isEmpty else { return .generalChat }

        if CommandIntentResolver.hasNegation(in: normalized) {
            return .advisory
        }

        if matchesAdvisory(normalized) {
            return .advisory
        }

        if matchesMutating(normalized) {
            return .mutatingWork
        }

        return .generalChat
    }

    private func matchesAdvisory(_ normalized: String) -> Bool {
        let advisoryPhrases = [
            "suggest",
            "recommend",
            "ideas",
            "what should",
            "next steps",
            "brainstorm",
            "explain",
            "compare",
            "opinion",
            "advice",
            "improvements",
            "ways to improve",
            "اقترح",
            "اقتراح",
            "انصح",
            "نصيحة",
            "ما رأيك",
            "اشرح",
            "قارن",
            "افكار",
            "أفكار",
            "خطوات",
            "عصف ذهني",
            "نصائح"
        ]

        return advisoryPhrases.contains { containsPhrase(normalized, $0) }
    }

    private func matchesMutating(_ normalized: String) -> Bool {
        if containsPhrase(normalized, "improve the")
            || containsPhrase(normalized, "improve code")
            || containsPhrase(normalized, "improve canvas") {
            return true
        }

        let mutatingWords = [
            "build",
            "create",
            "update",
            "fix",
            "implement",
            "make",
            "remove",
            "style",
            "document",
            "draft",
            "navigate",
            "انشاء",
            "اضف",
            "أضف",
            "عدل",
            "غير",
            "حدث",
            "اصلح",
            "اكتب",
            "وثق",
            "افتح",
            "اذهب"
        ]

        if mutatingWords.contains(where: { containsWord(normalized, $0) }) {
            return true
        }

        let mutatingPhrases = [
            "write the",
            "change the",
            "add a",
            "rewrite the",
            "add an",
            "fix the",
            "update the",
            "build a",
            "build an",
            "create a",
            "create an",
            "implement a",
            "implement an"
        ]

        return mutatingPhrases.contains { containsPhrase(normalized, $0) }
    }

    private func containsWord(_ normalized: String, _ word: String) -> Bool {
        let normalizedWord = CommandIntentResolver.normalizedCommandInput(word)
        guard !normalizedWord.isEmpty else { return false }
        guard !normalizedWord.contains(" ") else {
            return containsPhrase(normalized, normalizedWord)
        }
        return " \(normalized) ".contains(" \(normalizedWord) ")
    }

    private func containsPhrase(_ normalized: String, _ phrase: String) -> Bool {
        let normalizedPhrase = CommandIntentResolver.normalizedCommandInput(phrase)
        guard !normalizedPhrase.isEmpty else { return false }
        return " \(normalized) ".contains(" \(normalizedPhrase) ")
    }
}
