# Environment setup for implementation agents

## Observed starting environment

Checked November 6, 2026:

- Repository: `/Users/yehiafahmy/QuranCarPlayer` on macOS, shell zsh.
- No app source, Xcode project, dependency manifest, or tests existed before these planning documents.
- `xcode-select -p` returned `/Library/Developer/CommandLineTools`.
- `xcodebuild -version` failed because the active developer directory is Command Line Tools, not full Xcode.
- No `/Applications/Xcode*.app` match was found. Xcode may exist elsewhere; discover before assuming it must be installed.
- The owner reports Apple Developer Program membership, an iPhone, and a CarPlay-equipped car. CarPlay entitlement approval has not been verified.
- Git reported no commits on main and a missing upstream reference. Inspect remotes before any push; no repository publishing or commit was performed during planning.

These are observations, not permanent facts. Recheck on the next agent's host. No working build has been verified.

## 1. Install or select full Xcode

Find an existing Xcode installation first. If absent, obtain a stable supported release from Apple. The owner may need to complete account sign-in, installation, license acceptance, and component installation. Choose a release compatible with the Mac, supported iPhone OS, and current App Store submission requirements; do not assume a version from this plan.

Open Xcode once, finish first-launch setup, and install an iOS simulator runtime. Prefer a per-process developer directory for command-line work rather than changing the machine-wide selection unnecessarily:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun swift --version
xcrun --sdk iphoneos --show-sdk-version
xcrun simctl list devices available
```

Use the actual installed Xcode path. Record Xcode build number, Swift version, SDK, macOS version, and chosen runtime in this document once known. If the owner wants a global selection, `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` is the conventional alternative, requiring local privileges.

## 2. Create the native app project

Proposed initial configuration:

- iOS app target named `QuranCarPlayer`, Swift, SwiftUI, with an Xcode project committed to the repository.
- Shared `QuranCarPlayer` scheme and meaningful unit-test target; add UI tests for key phone flows once screens exist.
- Provisional minimum iOS 17; verify against owner hardware and selected SDK before fixing it.
- Unique reverse-DNS bundle ID chosen for the owner's developer team. Do not fabricate a production organization identifier.
- English and Arabic resources in a String Catalog, plus verified bilingual catalog data.
- CarPlay scene configuration/delegate alongside the phone scene, following the current Apple audio sample. The sample may use Apple Music; this app must not inherit MusicKit tokens, subscriptions, or Apple Music dependencies.
- Background Modes: audio playback. CarPlay audio entitlement: `com.apple.developer.carplay-audio` as documented by Apple.
- No microphone, location, contacts, or tracking permission is needed for the defined v1 scope.

Commit project configuration and shared schemes. Ignore build output, DerivedData, user-specific Xcode state, credentials, signing keys, and local configuration. Do not introduce CocoaPods, a JavaScript toolchain, or backend services without an actual requirement.

## 3. Signing and CarPlay access

In Xcode settings, the owner signs into their Apple account. Select the owner's team in Signing & Capabilities and use automatic signing where suitable. Never store passwords, certificates/private keys, or App Store Connect keys in source control.

Check whether the team/App ID already has Apple's CarPlay audio managed capability. If not, prepare the app purpose and request instructions for the owner. Adding a Boolean to an entitlements file does not by itself confer physical-device distribution access. Ensure the App ID, profile, bundle ID, and target entitlement agree after approval.

Pair the iPhone with Xcode, enable Developer Mode as required, build and run the basic phone app, then test background and lock-screen playback. Use the current Apple simulator instructions to configure CarPlay; menus/tool packaging can vary by Xcode version. Record exact successful steps for the installed version instead of guessing legacy menu paths.

## 4. Repeatable build and test commands

The following are intended commands AFTER creating the proposed project and shared scheme. They cannot work in the current documentation-only repository.

```sh
xcodebuild -list -project QuranCarPlayer.xcodeproj
xcodebuild -showdestinations -project QuranCarPlayer.xcodeproj -scheme QuranCarPlayer
xcodebuild -project QuranCarPlayer.xcodeproj -scheme QuranCarPlayer -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/QuranCarPlayer-DerivedData build
```

For tests, replace `SIMULATOR_UDID` with a real available destination from `-showdestinations`:

```sh
xcodebuild -project QuranCarPlayer.xcodeproj -scheme QuranCarPlayer -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' -derivedDataPath /tmp/QuranCarPlayer-DerivedData test
```

Do not report a generic simulator build as a device-signing test. Do not report an unavailable simulator or missing entitlement as an application test failure. Capture the actual failing prerequisite.

## 5. Audio development setup

Use a bundled mock catalog and test-owned audio for deterministic development until production permissions and URLs are verified. Mock audio is only a test fixture, never presented as Quran content in a release. Keep network integration tests separate from routine unit tests. No production API credential requirement has been established; if a selected provider later requires secrets, do not embed privileged credentials in the iOS app.

## 6. Physical-car test preparation

Record iPhone model/OS, Xcode version, car/head-unit model, and wired/wireless transport. Test parked, or have a passenger operate and observe while a driver focuses on driving. Cover cold connection, reconnection, locked phone, interruption, other audio apps, and poor connectivity. CarPlay Simulator alone cannot establish real connection/autoplay behavior.

## Setup completion checklist

- [ ] Full Xcode selected; exact versions recorded.
- [ ] iOS runtime available and app builds in simulator.
- [ ] Shared scheme and repeatable test commands verified.
- [ ] Owner team and unique bundle ID configured locally.
- [ ] CarPlay entitlement status and profile verified.
- [ ] App runs on owner's phone and appears in CarPlay.
- [ ] Source permissions and catalog verification recorded separately.

## Official references

- [Requesting CarPlay entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)
- [Using the CarPlay Simulator](https://developer.apple.com/documentation/carplay/using-the-carplay-simulator)
- [CarPlay developer resources and additional tools](https://developer.apple.com/carplay/)
- [Running on simulated or physical devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
- [Enabling Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
