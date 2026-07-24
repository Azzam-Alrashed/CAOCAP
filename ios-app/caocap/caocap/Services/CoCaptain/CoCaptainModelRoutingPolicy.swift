import Foundation
import Network

enum CoCaptainModelRoute: Equatable {
    case cloud(modelName: String)
    case local
    case unavailableOffline
}

enum CoCaptainConnectivityStatus: Equatable {
    case unknown
    case connected
    case disconnected

    var permitsCloudRouting: Bool {
        self == .connected
    }
}

public enum CoCaptainSubmissionError: LocalizedError, Equatable {
    case attachmentsRequireCloud

    public var errorDescription: String? {
        switch self {
        case .attachmentsRequireCloud:
            return String(
                localized: "On-device Gemma is text-only. Connect to the internet and choose Gemini to send attachments."
            )
        }
    }
}

enum CoCaptainRoutingError: LocalizedError, Equatable {
    case offlineModelUnavailable

    var errorDescription: String? {
        switch self {
        case .offlineModelUnavailable:
            return String(
                localized: "CoCaptain is offline and Gemma 4 is not ready. Connect to the internet or download Gemma 4 in Settings."
            )
        }
    }
}

enum CoCaptainModelRoutingPolicy {
    static func route(
        requestedModelName: String?,
        eligibility: LocalModelDeviceEligibility,
        isLocalModelReady: Bool,
        connectivity: CoCaptainConnectivityStatus
    ) -> CoCaptainModelRoute {
        if !connectivity.permitsCloudRouting {
            return eligibility.isSupported && isLocalModelReady
                ? .local
                : .unavailableOffline
        }

        let resolvedModelName = CoCaptainModelSelectionPolicy.resolvedModelName(
            requestedModelName,
            eligibility: eligibility
        )
        if resolvedModelName == CoCaptainModelSelectionPolicy.localModelName {
            return .local
        }
        return .cloud(modelName: resolvedModelName)
    }
}

/// Thread-safe connectivity state used by both prompt construction and model routing.
final class NetworkConnectivityMonitor: @unchecked Sendable {
    static let shared = NetworkConnectivityMonitor()

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.caocap.app.NetworkConnectivityMonitor")
    private let lock = NSLock()
    private var status = CoCaptainConnectivityStatus.unknown

    var currentStatus: CoCaptainConnectivityStatus {
        lock.withLock { status }
    }

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            self?.lock.withLock {
                self?.status = path.status == .satisfied ? .connected : .disconnected
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
