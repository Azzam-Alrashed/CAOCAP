import Foundation

/// Classifies what the user wants from a single CoCaptain turn before the
/// coordinator selects execution policy and LLM prompt instructions.
public enum CoCaptainTurnIntent: Hashable {
    /// The user asked to build, edit, or otherwise change canvas content.
    case mutatingWork
    /// The user asked for advice, suggestions, or analysis without applying changes.
    case advisory
    /// Casual conversation with no advisory or build/edit signals.
    case generalChat

    /// Connection-fallback footers apply only when executable canvas work was expected.
    var requiresDegradedConnectionNotice: Bool {
        self == .mutatingWork
    }

    /// Turn-specific prompt guidance appended after purpose instructions.
    var promptInstructions: String? {
        switch self {
        case .mutatingWork:
            return nil
        case .advisory:
            return """
            Advisory turn objective:
            - The user is asking for suggestions, recommendations, explanations, comparisons, or opinions — not requesting canvas changes yet.
            - Answer in clear prose grounded in the supplied context when helpful.
            - Do not request app actions and do not append a `cocaptain_actions` block.
            - Match the language used by the user.
            """
        case .generalChat:
            return """
            General chat objective:
            - The user is having a casual conversation unrelated to making canvas changes.
            - Answer naturally and concisely.
            - Do not request app actions and do not append a `cocaptain_actions` block.
            - Match the language used by the user.
            """
        }
    }
}
