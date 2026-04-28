import Foundation

public struct CommandIntentResolver {
    public init() {}

    public func resolve(_ input: String, availableActions: [AppActionDefinition]) -> AppActionID? {
        let normalizedInput = Self.normalized(input)
        guard !normalizedInput.isEmpty else { return nil }
        guard !Self.hasNegation(in: normalizedInput) else { return nil }

        let availableIDs = Set(availableActions.map(\.id))
        return AppActionID.allCases.first { id in
            availableIDs.contains(id) && aliases(for: id).contains { alias in
                Self.matches(normalizedInput, alias: alias)
            }
        }
    }

    private func aliases(for id: AppActionID) -> [String] {
        switch id {
        case .goHome:
            return [
                "go home",
                "home",
                "take me home",
                "open home",
                "الرئيسية",
                "اذهب للرئيسية",
                "اذهب الى الرئيسية",
                "افتح الرئيسية",
                "الصفحة الرئيسية"
            ]
        case .goBack:
            return [
                "go back",
                "back",
                "return",
                "ارجع",
                "رجوع",
                "عد للخلف",
                "ارجع للخلف"
            ]
        case .newProject:
            return [
                "new project",
                "create project",
                "create a project",
                "make project",
                "make a project",
                "start project",
                "start a project",
                "create new project",
                "مشروع جديد",
                "انشاء مشروع",
                "انشاء مشروع جديد",
                "أنشئ مشروع",
                "أنشئ مشروع جديد",
                "سوي مشروع",
                "سوي مشروع جديد",
                "اصنع مشروع",
                "ابدأ مشروع"
            ]
        case .createNode:
            return [
                "create node",
                "create a node",
                "new node",
                "add node",
                "add a node",
                "انشاء عقدة",
                "انشاء عقدة جديدة",
                "أضف عقدة",
                "اضف عقدة",
                "عقدة جديدة",
                "سوي عقدة"
            ]
        case .summonCoCaptain:
            return [
                "summon cocaptain",
                "open cocaptain",
                "open co captain",
                "show cocaptain",
                "افتح المساعد",
                "افتح مساعد الذكاء الاصطناعي",
                "استدع المساعد"
            ]
        case .openFile:
            return [
                "open file",
                "choose file",
                "افتح ملف",
                "اختر ملف"
            ]
        case .toggleGrid:
            return [
                "toggle grid",
                "show grid",
                "hide grid",
                "الشبكة",
                "اظهر الشبكة",
                "اخف الشبكة"
            ]
        case .shareProject:
            return [
                "share project",
                "share",
                "مشاركة المشروع",
                "شارك المشروع",
                "مشاركة"
            ]
        case .proSubscription:
            return [
                "pro subscription",
                "upgrade",
                "subscribe",
                "اشتراك",
                "اشترك",
                "ترقية",
                "الاشتراك الاحترافي"
            ]
        case .signIn:
            return [
                "sign in",
                "login",
                "log in",
                "تسجيل الدخول",
                "سجل الدخول",
                "ادخل"
            ]
        case .openSettings:
            return [
                "open settings",
                "settings",
                "اعدادات",
                "الإعدادات",
                "افتح الاعدادات",
                "افتح الإعدادات"
            ]
        case .openProfile:
            return [
                "open profile",
                "profile",
                "الحساب",
                "الملف الشخصي",
                "افتح الحساب",
                "افتح الملف الشخصي"
            ]
        case .openProjectExplorer:
            return [
                "project explorer",
                "open projects",
                "show projects",
                "projects",
                "المشاريع",
                "افتح المشاريع",
                "اعرض المشاريع",
                "مستكشف المشاريع"
            ]
        case .help:
            return [
                "help",
                "open help",
                "documentation",
                "مساعدة",
                "المساعدة",
                "افتح المساعدة",
                "التوثيق"
            ]
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^\\p{L}\\p{N}]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matches(_ normalizedInput: String, alias: String) -> Bool {
        let normalizedAlias = normalized(alias)
        guard !normalizedAlias.isEmpty else { return false }
        guard normalizedInput != normalizedAlias else { return true }
        guard normalizedAlias.contains(" ") else { return false }
        return " \(normalizedInput) ".contains(" \(normalizedAlias) ")
    }

    private static func hasNegation(in normalizedInput: String) -> Bool {
        let negations = [
            "dont",
            "do not",
            "never",
            "لا",
            "لات",
            "مو",
            "مش"
        ]

        return negations.contains { negation in
            " \(normalizedInput) ".contains(" \(normalized(negation)) ")
        }
    }
}
