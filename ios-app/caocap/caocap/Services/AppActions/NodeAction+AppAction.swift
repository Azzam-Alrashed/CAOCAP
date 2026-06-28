import Foundation

extension NodeAction {
    /// The registered app action that executes this canvas node action.
    public var appActionID: AppActionID? {
        switch self {
        case .navigateRoot: return .goRoot
        case .openSettings: return .openSettings
        case .openProfile: return .openProfile
        case .summonCoCaptain: return .summonCoCaptain
        case .proSubscription: return .proSubscription
        case .openActivity: return .openActivity
        case .openDaily: return .openDaily
        case .openWhatsApp: return .openWhatsApp
        case .openHelp: return .help
        }
    }
}
