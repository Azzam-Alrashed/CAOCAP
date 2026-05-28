import Foundation

public enum NodeTheme: String, Codable, CaseIterable {
    case purple, blue, pink, orange, green, indigo, cyan, secondary
    
    public var localizedDisplayName: String {
        LocalizationManager.shared.localizedString(rawValue.capitalized)
    }
}

