import Testing
@testable import caocap

struct CoCaptainModelRoutingPolicyTests {
    @Test func offlineWithReadyLocalModelRoutesToGemma() {
        let route = CoCaptainModelRoutingPolicy.route(
            requestedModelName: CoCaptainModelSelectionPolicy.cloudModelName,
            eligibility: supportedDevice,
            isLocalModelReady: true,
            connectivity: .disconnected
        )

        #expect(route == .local)
    }

    @Test func offlineWithoutReadyLocalModelIsUnavailable() {
        let route = CoCaptainModelRoutingPolicy.route(
            requestedModelName: CoCaptainModelSelectionPolicy.cloudModelName,
            eligibility: supportedDevice,
            isLocalModelReady: false,
            connectivity: .disconnected
        )

        #expect(route == .unavailableOffline)
    }

    @Test func unsupportedDeviceCannotUseLocalModelOffline() {
        let route = CoCaptainModelRoutingPolicy.route(
            requestedModelName: CoCaptainModelSelectionPolicy.localModelName,
            eligibility: unsupportedDevice,
            isLocalModelReady: true,
            connectivity: .disconnected
        )

        #expect(route == .unavailableOffline)
    }

    @Test func returningOnlineRestoresExplicitCloudPreference() {
        let route = CoCaptainModelRoutingPolicy.route(
            requestedModelName: CoCaptainModelSelectionPolicy.cloudModelName,
            eligibility: supportedDevice,
            isLocalModelReady: true,
            connectivity: .connected
        )

        #expect(route == .cloud(modelName: CoCaptainModelSelectionPolicy.cloudModelName))
    }

    @Test func onlineExplicitLocalPreferenceStaysLocal() {
        let route = CoCaptainModelRoutingPolicy.route(
            requestedModelName: CoCaptainModelSelectionPolicy.localModelName,
            eligibility: supportedDevice,
            isLocalModelReady: true,
            connectivity: .connected
        )

        #expect(route == .local)
    }

    @Test func unknownConnectivityNeverAttemptsCloud() {
        let route = CoCaptainModelRoutingPolicy.route(
            requestedModelName: CoCaptainModelSelectionPolicy.cloudModelName,
            eligibility: supportedDevice,
            isLocalModelReady: false,
            connectivity: .unknown
        )

        #expect(route == .unavailableOffline)
    }

    private var supportedDevice: LocalModelDeviceEligibility {
        LocalModelDeviceEligibility(family: .phone, hardwareIdentifier: "iPhone16,1")
    }

    private var unsupportedDevice: LocalModelDeviceEligibility {
        LocalModelDeviceEligibility(family: .phone, hardwareIdentifier: "iPhone15,5")
    }
}
