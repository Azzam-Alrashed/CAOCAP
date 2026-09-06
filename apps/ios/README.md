# CAOCAP for iOS

SwiftUI shell targeting iOS 26 or later. Requires full Xcode with a compatible iOS SDK.

What is here today is a leftover **canvas + CoCaptain + sign-in** app, not a mini-app studio and not the planned Explore / Build / Collaborate product.

- **Home** is an empty spatial canvas. You can pan, zoom, create ordinary cards, connect them, save, and undo.
- **CoCaptain / CoStar** is a chat that talks about the canvas and can request canvas actions such as creating or moving a card. It does not edit HTML or SRS.
- **Sign-in** uses Firebase Auth (anonymous first, then Apple / Google / GitHub).
- **CAOCAP Pro** is a purchase screen in Settings / Profile (and from CoCaptain when free-tier usage hits the limit). It is not a Home card.

Explore, mindmaps, Collaborate, and agent-version publish are planned. They are not implemented in this app.

## Setup

1. Open [caocap.xcodeproj](caocap/caocap.xcodeproj) and let Xcode resolve its Swift packages.
2. Register an iOS app in your Firebase project using the app target's bundle identifier (currently `com.Ficruty.caocap`). Add its `GoogleService-Info.plist` to the `caocap` target so it is included in the app bundle.
3. For Google sign-in, enable the Google provider in Firebase Authentication and replace the Google URL scheme in [Info.plist](caocap/caocap/Resources/Config/Info.plist) with your configuration's `REVERSED_CLIENT_ID`.
4. Select the `caocap` scheme and an iOS 26 or later simulator. For a physical device, configure your development team under **Signing & Capabilities**.
5. Run with **Product → Run** or `Command-R`.

Firebase configuration is required at launch. CoCaptain cloud chat also needs the project's Firebase AI / Gemini setup. Individual features may require additional service setup.

## What you should see

On a fresh install, intro and persona pick come first. Then Home is blank except the HUD and FAB. You can still pan and zoom. Settings, Profile, Help, sign-in, CoCaptain, and CAOCAP Pro stay reachable from the HUD and command palette. If a simulator still shows old Home cards, delete the app and run again.

## Related notes

- [Canvas](caocap/caocap/Features/Canvas/README.md)
- [CoCaptain](caocap/caocap/Features/CoCaptain/README.md)
- [App session](caocap/caocap/Services/AppSession/README.md)
- [Auth](caocap/caocap/Features/Auth/README.md)
- [Subscription](caocap/caocap/Features/Subscription/README.md)
