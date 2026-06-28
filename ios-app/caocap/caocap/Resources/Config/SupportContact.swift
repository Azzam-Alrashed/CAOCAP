import Foundation

enum SupportContact {
    /// International phone number without + or spaces (wa.me format).
    static let whatsAppPhoneE164 = "966559279486"

    static var whatsAppURL: URL? {
        URL(string: "https://wa.me/\(whatsAppPhoneE164)")
    }
}
