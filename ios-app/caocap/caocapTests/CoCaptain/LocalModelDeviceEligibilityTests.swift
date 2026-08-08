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

    @Test func supportsMSeriesIPads() {
        for identifier in [
            "iPad13,4",  // M1 iPad Pro
            "iPad13,16", // M1 iPad Air
            "iPad14,3",  // M2 iPad Pro
            "iPad14,8",  // M2 iPad Air
            "iPad15,3",  // M3 iPad Air
            "iPad16,3",  // M4 iPad Pro
            "iPad16,8",  // M4 iPad Air
            "iPad17,1"   // M5 iPad Pro
        ] {
            #expect(eligibility(identifier, family: .pad).isSupported)
        }
    }

    @Test func rejectsASeriesIPads() {
        for identifier in ["iPad13,19", "iPad15,7", "iPad16,1"] {
            #expect(!eligibility(identifier, family: .pad).isSupported)
        }
    }

    @Test func permitsSimulatorForDevelopmentAndUIVerification() {
        let result = LocalModelDeviceEligibility(
            family: .phone,
            hardwareIdentifier: "arm64",
            isSimulator: true
        )

        #expect(result.isSupported)

        let iPadResult = LocalModelDeviceEligibility(
            family: .pad,
            hardwareIdentifier: "arm64",
            isSimulator: true
        )

        #expect(iPadResult.isSupported)
    }

    @Test func unsupportedPersistedLocalSelectionFallsBackToCloud() {
        let result = CoCaptainModelSelectionPolicy.resolvedModelName(
            CoCaptainModelSelectionPolicy.localModelName,
            eligibility: eligibility("iPhone15,5")
        )

        #expect(result == CoCaptainModelSelectionPolicy.cloudModelName)
    }

    @Test func legacyCloudModelNamesMigrateToCurrentDefault() {
        #expect(
            CoCaptainModelSelectionPolicy.resolvedModelName("gemini-3-flash-preview")
                == CoCaptainModelSelectionPolicy.cloudModelName
        )
        #expect(
            CoCaptainModelSelectionPolicy.resolvedModelName("gemini-3.5-flash")
                == CoCaptainModelSelectionPolicy.cloudModelName
        )
    }

    @Test func supportedPersistedLocalSelectionIsPreserved() {
        let result = CoCaptainModelSelectionPolicy.resolvedModelName(
            CoCaptainModelSelectionPolicy.localModelName,
            eligibility: eligibility("iPhone16,1")
        )

        #expect(result == CoCaptainModelSelectionPolicy.localModelName)
    }

    @Test func supportedIPadPersistedLocalSelectionIsPreserved() {
        let result = CoCaptainModelSelectionPolicy.resolvedModelName(
            CoCaptainModelSelectionPolicy.localModelName,
            eligibility: eligibility("iPad16,8", family: .pad)
        )

        #expect(result == CoCaptainModelSelectionPolicy.localModelName)
    }

    private func eligibility(
        _ identifier: String,
        family: LocalModelDeviceEligibility.DeviceFamily = .phone
    ) -> LocalModelDeviceEligibility {
        LocalModelDeviceEligibility(
            family: family,
            hardwareIdentifier: identifier
        )
    }
}
