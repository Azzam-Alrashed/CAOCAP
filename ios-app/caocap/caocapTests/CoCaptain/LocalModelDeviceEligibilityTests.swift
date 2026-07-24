import Testing
@testable import caocap

struct LocalModelDeviceEligibilityTests {
    @Test func supportsIPhone15ProFamily() {
        #expect(eligibility("iPhone16,1").isSupported)
        #expect(eligibility("iPhone16,2").isSupported)
    }

    @Test func supportsNewerIPhones() {
        #expect(eligibility("iPhone17,1").isSupported)
        #expect(eligibility("iPhone18,4").isSupported)
    }

    @Test func rejectsOlderAndNonProIPhones() {
        #expect(!eligibility("iPhone15,5").isSupported)
        #expect(!eligibility("iPhone15,4").isSupported)
    }

    @Test func rejectsIPadRegardlessOfIdentifierGeneration() {
        let result = LocalModelDeviceEligibility(
            family: .pad,
            hardwareIdentifier: "iPad17,1"
        )

        #expect(!result.isSupported)
    }

    @Test func permitsSimulatorForDevelopmentAndUIVerification() {
        let result = LocalModelDeviceEligibility(
            family: .phone,
            hardwareIdentifier: "arm64",
            isSimulator: true
        )

        #expect(result.isSupported)
    }

    @Test func unsupportedPersistedLocalSelectionFallsBackToCloud() {
        let result = CoCaptainModelSelectionPolicy.resolvedModelName(
            CoCaptainModelSelectionPolicy.localModelName,
            eligibility: eligibility("iPhone15,5")
        )

        #expect(result == CoCaptainModelSelectionPolicy.cloudModelName)
    }

    @Test func supportedPersistedLocalSelectionIsPreserved() {
        let result = CoCaptainModelSelectionPolicy.resolvedModelName(
            CoCaptainModelSelectionPolicy.localModelName,
            eligibility: eligibility("iPhone16,1")
        )

        #expect(result == CoCaptainModelSelectionPolicy.localModelName)
    }

    private func eligibility(_ identifier: String) -> LocalModelDeviceEligibility {
        LocalModelDeviceEligibility(
            family: .phone,
            hardwareIdentifier: identifier
        )
    }
}
