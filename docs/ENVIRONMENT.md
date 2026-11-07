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

## Observed on November 6, 2026 (implementation session)

Rechecked on the same Mac after the planning session:

- macOS 27.0.1 (build 26A434), Apple Silicon (arm64).
- **Full Xcode is still not installed.** Searched `/Applications`, `~/Applications`, Spotlight, and `find / -maxdepth 4`. Only `/Library/Developer/CommandLineTools` exists; `xcodebuild` and `simctl` are unavailable, and there is no iOS SDK. **Installing Xcode requires the owner's Apple account (see "Owner actions" below).**
- Command Line Tools provide Swift 6.4 (`swiftlang-6.4.0.34.1`) with the macOS 27.0 SDK. `swift build` and `swift test` work for macOS targets. XCTest is **not** shipped with the CLT; Swift Testing is, but its macro plugin must be passed explicitly (see `Scripts/test-core.sh`).
- Homebrew 7.0.12 present. Installed `xcodegen` 2.46.0 (bottled) to generate the Xcode project from `project.yml`. XcodeGen is a development tool only; the generated project is committed and does not require it.
- `afconvert` (macOS) available; used to produce the AAC test tones.
- Git: branch `main` tracks `origin/main` (`git@github.com:Yehia-Fahmy/QuranCarPlayer.git`), one commit. Work for this session is on `codex/milestone-0-foundation`; nothing was pushed.
- Disk: ~286 GB free, enough for Xcode and simulator runtimes.

### What was verified on this Mac

- `Scripts/test-core.sh`: core package builds and **48 tests in 7 suites pass** (macOS, fake audio engine, injected clock/scheduler).
- `Packages/QuranCarPlayerCore` compiles including the `AVPlayerEngine` and `NowPlayingBridge` (AVFoundation/MediaPlayer are available on macOS). `AudioSessionController` is `#if os(iOS)` and was not compiled.
- All files in `App/Sources` and `AppTests` pass `swiftc -parse` (syntax only). **They have not been type-checked or built**, because that needs the iOS SDK.
- `QuranCarPlayer.xcodeproj` was generated and inspected (scheme shared, package linked, entitlements and Info.plist scene manifest present). It has not been opened in Xcode.

### Owner actions required

1. ~~Install Xcode.~~ Done: Xcode 27.2 (27B52).
2. ~~Sign in to Xcode~~ Owner reports signed in. No development certificate exists yet (`security find-identity` returned 0 identities); the first device build with a team selected will create one.
3. **Choose a bundle ID** you control (reverse-DNS, e.g. based on a domain you own) and your Team ID; put them in `Config/Signing.xcconfig` (copy from `Config/Signing.xcconfig.example`). The committed default `local.placeholder.QuranCarPlayer` is for simulator builds only.
4. **Request the CarPlay audio entitlement** at https://developer.apple.com/contact/carplay/ for that bundle ID, describing the app as a Quran audio player for surah/reciter selection and playback in the car. Approval can take days to weeks and is required before the app will run on your phone with CarPlay. After approval, enable the CarPlay Audio capability on the App ID in Certificates, Identifiers & Profiles and regenerate the provisioning profile.
5. Later: enable Developer Mode on the iPhone and pair it with Xcode for device testing; in-car testing needs you (or a passenger) with the parked car.

## Observed later on November 6, 2026 (after the owner installed Xcode)

- **Xcode 27.2 (27B52)** at `/Applications/Xcode.app`, globally selected (`xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`). iOS SDK 27.2, iOS Simulator SDK 27.2. Owner reports being signed in to Xcode.
- `xcodebuild -project QuranCarPlayer.xcodeproj -scheme QuranCarPlayer -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/QuranCarPlayer-DerivedData build` → **BUILD SUCCEEDED, zero compiler warnings or errors**, first attempt. The bundle contains the CarPlay scene delegate class, both `.lproj` folders, the test tones, and the `carplay-audio` entitlement.
- No iOS simulator runtime was installed with Xcode. Started `xcodebuild -downloadPlatform iOS` (multi-GB download). Until it finishes, `simctl` reports no runtimes and nothing can run or be tested in a simulator.
- `security find-identity -v -p codesigning` → 0 identities (normal until the first device build with a team selected). `xcrun devicectl list devices` → no iPhone connected.
- Simulator-only bundle ID in use: `local.placeholder.QuranCarPlayer` (from `Config/Shared.xcconfig`). Device builds still need `Config/Signing.xcconfig`.

## Observed on November 7, 2026 (simulator runtime arrived)

- iOS Simulator runtime **iOS 27.2 (27.2 — 24B8117)** is installed. Available devices include iPhone 17 (`6A7BEB9D-5E0D-455D-A67E-B920AFC202FE`).
- App tests: `xcodebuild … -destination 'platform=iOS Simulator,id=6A7BEB9D-5E0D-455D-A67E-B920AFC202FE' test` → **TEST SUCCEEDED**. Swift Testing suite "App bundle configuration": **5 tests passed** (CarPlay scene delegate class resolves, background audio mode, test-tone files bundled, en/ar strings, composition root).
- Installed and launched on that simulator (`local.placeholder.QuranCarPlayer`, pid recorded). Screenshot of first launch: Surahs list in Quran order, header "Reciter: Test Tone A (not Quran)", reciter and settings toolbar buttons present. **Playback, seek, reciter change, and settings were not tapped in this session.**
- Xcode 27.2 no longer ships `Simulator.app` at the legacy path (`/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app` is absent). Device UI lives in `DeviceHub.app` (`com.apple.dt.Devices`). Apple's CarPlay Simulator docs still say: run in the iOS simulator, then **I/O ▸ External Displays ▸ CarPlay**. That menu was not opened from the command line; CarPlay UI remains untested.
- Swift version used by this Xcode: confirm with `xcrun swift --version` if needed; iOS SDK 27.2.

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

See [BUILD_AND_TEST.md](BUILD_AND_TEST.md) for the maintained procedure. Core tests: `Scripts/test-core.sh`. Simulator destination used 2026-11-07: iPhone 17, `6A7BEB9D-5E0D-455D-A67E-B920AFC202FE`. Re-check with `-showdestinations` if devices change.

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

- [x] Full Xcode selected; exact versions recorded. Xcode 27.2 (27B52), iOS SDK 27.2 (2026-11-06, later the same day).
- [x] iOS runtime available and app builds in simulator. iOS 27.2 (24B8117); simulator **build succeeded** (zero compiler warnings) and **app tests passed** (5/5) on iPhone 17. App launched; first-launch Surahs screen verified by screenshot. CarPlay Simulator window not yet opened.
- [x] Shared scheme committed (`QuranCarPlayer.xcodeproj/xcshareddata/xcschemes/QuranCarPlayer.xcscheme`). Core test command verified (`Scripts/test-core.sh`, 48 tests pass). `xcodebuild` commands not yet verified.
- [ ] Owner team and unique bundle ID configured locally (`Config/Signing.xcconfig`). Mechanism in place; values pending from owner.
- [ ] CarPlay entitlement status and profile verified. Entitlements file committed; approval not requested yet.
- [ ] App runs on owner's phone and appears in CarPlay.
- [ ] Source permissions and catalog verification recorded separately. Not started; app uses test tones.

## Official references

- [Requesting CarPlay entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)
- [Using the CarPlay Simulator](https://developer.apple.com/documentation/carplay/using-the-carplay-simulator)
- [CarPlay developer resources and additional tools](https://developer.apple.com/carplay/)
- [Running on simulated or physical devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
- [Enabling Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
