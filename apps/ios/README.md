# CAOCAP for iOS

SwiftUI app targeting iOS 26 or later. Requires full Xcode with a compatible iOS SDK.

## Setup

1. Open [caocap.xcodeproj](caocap/caocap.xcodeproj) and let Xcode resolve its Swift packages.
2. Register an iOS app in your Firebase project using the app target's bundle identifier (currently `com.Ficruty.caocap`). Add its `GoogleService-Info.plist` to the `caocap` target so it is included in the app bundle.
3. For Google sign-in, enable the Google provider in Firebase Authentication and replace the Google URL scheme in [Info.plist](caocap/caocap/Resources/Config/Info.plist) with your configuration's `REVERSED_CLIENT_ID`.
4. Select the `caocap` scheme and an iOS 26 or later simulator. For a physical device, configure your development team under **Signing & Capabilities**.
5. Run with **Product → Run** or `Command-R`.

Firebase configuration is required at launch. Individual features may require additional service setup.
