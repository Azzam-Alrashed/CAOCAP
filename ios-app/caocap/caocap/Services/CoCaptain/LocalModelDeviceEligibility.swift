import Foundation

/// Pure capability rule for exposing the on-device Gemma model.
///
/// Apple hardware identifiers are used instead of the marketing OS version:
/// `iPhone16,1` and `iPhone16,2` are the iPhone 15 Pro family, while later
/// identifier generations represent newer iPhones with the required memory
/// and compute floor.
public struct LocalModelDeviceEligibility: Equatable, Sendable {
    public enum DeviceFamily: Equatable, Sendable {
        case phone
        case pad
        case other
    }

    public enum Status: Equatable, Sendable {
        case supported
        case unsupported
    }

    public let status: Status

    public var isSupported: Bool {
        status == .supported
    }

    public static let current = LocalModelDeviceEligibility(
        family: currentDeviceFamily,
        hardwareIdentifier: currentHardwareIdentifier,
        isSimulator: isRunningInSimulator
    )

    public init(
        family: DeviceFamily,
        hardwareIdentifier: String,
        isSimulator: Bool = false
    ) {
        guard family == .phone else {
            status = .unsupported
            return
        }

        if isSimulator {
            status = .supported
            return
        }

        guard let components = Self.iPhoneIdentifierComponents(hardwareIdentifier) else {
            status = .unsupported
            return
        }

        let is15ProFamily = components.major == 16
            && (components.minor == 1 || components.minor == 2)
        let isNewerIPhone = components.major >= 17
        status = is15ProFamily || isNewerIPhone ? .supported : .unsupported
    }

    private static func iPhoneIdentifierComponents(
        _ identifier: String
    ) -> (major: Int, minor: Int)? {
        guard identifier.hasPrefix("iPhone") else { return nil }

        let version = identifier.dropFirst("iPhone".count)
        let parts = version.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let major = Int(parts[0]),
              let minor = Int(parts[1]) else {
            return nil
        }
        return (major, minor)
    }

    private static var currentDeviceFamily: DeviceFamily {
        let identifier = currentHardwareIdentifier
        if identifier.hasPrefix("iPhone") { return .phone }
        if identifier.hasPrefix("iPad") { return .pad }
        return isRunningInSimulator ? .phone : .other
    }

    private static var currentHardwareIdentifier: String {
        #if targetEnvironment(simulator)
        if let simulatedIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatedIdentifier
        }
        #endif

        var systemInfo = utsname()
        uname(&systemInfo)

        return Mirror(reflecting: systemInfo.machine).children.reduce(into: "") { identifier, element in
            guard let byte = element.value as? Int8, byte != 0 else { return }
            identifier.append(Character(UnicodeScalar(UInt8(byte))))
        }
    }

    private static var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}

/// Resolves persisted model choices against the current device capability.
public enum CoCaptainModelSelectionPolicy {
    public static let cloudModelName = "gemini-3-flash-preview"
    public static let localModelName = "gemma-4-local"

    public static func resolvedModelName(
        _ requestedModelName: String?,
        eligibility: LocalModelDeviceEligibility = .current
    ) -> String {
        guard requestedModelName == localModelName else {
            guard let trimmed = requestedModelName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                return cloudModelName
            }
            return trimmed
        }

        return eligibility.isSupported ? localModelName : cloudModelName
    }
}
