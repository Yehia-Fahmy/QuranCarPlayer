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
2. ~~Sign in to Xcode~~ Done as `yehia.fahmy@uwaterloo.ca`. On 2026-11-14 that account’s only team is the free Personal Team `FUT64434V9`. The paid Developer Program team from the same day’s membership order is not listed yet.
3. ~~Choose a bundle ID~~ Done locally in gitignored `Config/Signing.xcconfig`: `com.yehiafahmy.QuranCarPlayerApp`, team `FUT64434V9`. `com.yehiafahmy.QuranCarPlayer` stays registered to the previous iCloud Personal Team and is not available here. The committed default `local.placeholder.QuranCarPlayer` remains for simulator builds. Move the Waterloo bundle ID to the paid team before requesting CarPlay.
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

## Observed later on November 7, 2026 (phone UI and device signing)

- Phone UI tests: **3 passed** on iPhone 17 simulator (`PhonePlaybackUITests`). Selecting a surah starts the labelled test tone; pause, next surah, reciter change, and Arabic settings were exercised.
- Physical device present and paired: Yehia's iPhone, iPhone 15 Pro Max, UDID `00008130-001C6C2C14DA001C`, iOS 27.0.1, Developer Mode on, USB. `devicectl list devices` shows it available.
- Device build **failed**: Xcode has no Apple ID ("No Accounts"). Local gitignored `Config/Signing.xcconfig` names Personal Team `MN7YP2FD68` and bundle ID `com.yehiafahmy.QuranCarPlayer`. The committed default remains `local.placeholder.QuranCarPlayer`. Phone signing uses `App/QuranCarPlayerPhone.entitlements` so a free team can install once an account is signed in. CarPlay entitlements stay in `App/QuranCarPlayer.entitlements` and are not on the phone build.
- CarPlay Simulator, observed earlier the same day with this phone in Device Hub: a car Home Screen appeared. QuranCarPlayer was not on it. A free Personal Team cannot sign `com.apple.developer.carplay-audio`, and the app was not installed. Paid membership was still waiting on Apple activation.

## Observed on November 14, 2026 (phone streaming)

- iPhone 15 Pro Max still connected (`00008130-001C6C2C14DA001C`, iOS 27.0.1). `devicectl device info apps` already listed QuranCarPlayer 0.1.0 before this session's rebuild.
- Development certificate present: subject `Apple Development: yehiafahmy@icloud.com (N5D9H3GUWQ)`, OU `MN7YP2FD68`, organization Yehia Fahmy, valid from 2026-11-07 through 2027-11-07. Xcode's `IDEProvisioningTeamByIdentifier` has one team, `isFreeProvisioningTeam = 1`.
- Device build and install succeeded with the existing 7-day profile (`e0478bbd`, created 2026-11-07 21:26, expires 2026-11-14 21:26). UI-test signing did not: no profile for `com.yehiafahmy.QuranCarPlayer.uitests.xctrunner`, and `xcodebuild` reported no account for team `MN7YP2FD68`.
- On-device playback, driven from the Mac with the phone unlocked: saved session An-Nisa paused; Al-Fatihah streamed (0:05 then 0:27 of 0:38); Al-Baqarah followed with duration 1:47:59 and was left paused at 0:32. No test-audio banner. Details in IMPLEMENTATION.md. That install was signed by the previous iCloud Personal Team and was removed later the same day.

## Observed later on November 14, 2026 (Apple ID change)

- Xcode ▸ Settings ▸ Apple Accounts shows `yehia.fahmy@uwaterloo.ca` with one team, Personal Team `FUT64434V9`.
- Device build for bundle ID `com.yehiafahmy.QuranCarPlayerApp` **BUILD SUCCEEDED**, signed `Apple Development: yehia.fahmy@uwaterloo.ca (3S7S6J2RD8)`.
- Installed on the iPhone. The previous `com.yehiafahmy.QuranCarPlayer` app was uninstalled. After the owner trusted the certificate, launch showed the Surahs list with Maher Al-Muaiqly selected.

## Observed later on November 14, 2026 (membership recheck)

The owner reported that the paid Apple Developer Program membership had just been approved. A recheck the same afternoon did not find a paid team, so the CarPlay entitlement file was not switched and CarPlay was not opened.

- Xcode Settings ▸ Apple Accounts for `yehia.fahmy@uwaterloo.ca` still lists one team. The row reads “YEHIA WALEED FAHMY”, role Admin, with the subtitle “Developer Team”, a check on Certificates, Identifiers, & Profiles, and “1 Provisioned Device”.
- `IDEProvisioningTeamByIdentifier` for that account still has one entry: `isFreeProvisioningTeam = 1`, team ID `FUT64434V9`, name “YEHIA WALEED FAHMY (Personal Team)”, `teamType` “Personal Team”. The Accounts subtitle does not change that record.
- Codesigning identities are unchanged: Waterloo certificate OU `FUT64434V9`, and the older iCloud certificate OU `MN7YP2FD68`. No other team ID.
- The newest profile, `32f7f1ea-7738-46c2-95e8-5b19674518d0`, was created 2026-11-14 17:30:50Z and expires 2026-11-21 17:30:50Z (seven days). It is team `FUT64434V9`, bundle `com.yehiafahmy.QuranCarPlayerApp`, and has no `com.apple.developer.carplay-audio`. Download Manual Profiles did not add a team or a profile.
- `xcodebuild … -destination 'platform=iOS,id=00008130-001C6C2C14DA001C' -allowProvisioningUpdates build` → **BUILD SUCCEEDED**, still using `App/QuranCarPlayerPhone.entitlements` and that seven-day profile. `Config/Signing.xcconfig` was left on team `FUT64434V9`. The phone stayed connected. CarPlay in Device Hub was not opened, and the app icon was not confirmed on a car Home Screen.

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
- [x] iOS runtime available and app builds in simulator. iOS 27.2 (24B8117); simulator build succeeded and app tests passed (5/5) on iPhone 17. Phone UI tests passed (3/3) on 2026-11-07.
- [x] Shared scheme committed (`QuranCarPlayer.xcodeproj/xcshareddata/xcschemes/QuranCarPlayer.xcscheme`). Core test command verified (`Scripts/test-core.sh`, 48 tests pass). `xcodebuild` simulator test verified.
- [x] Owner team and bundle ID configured locally (`Config/Signing.xcconfig`, gitignored): Apple ID `yehia.fahmy@uwaterloo.ca`, Personal Team `FUT64434V9`, bundle ID `com.yehiafahmy.QuranCarPlayerApp`. The owner trusted that certificate and the app launched on the iPhone (2026-11-14). A later recheck the same day, after the owner reported membership approval, still lists only this free team (`isFreeProvisioningTeam = 1`).
- [ ] CarPlay entitlement status and profile verified. Phone builds deliberately omit it. The paid team was still absent on the 2026-11-14 afternoon recheck, so `QCP_CODE_SIGN_ENTITLEMENTS` was not pointed at `App/QuranCarPlayer.entitlements`. See IMPLEMENTATION.md "Open: CarPlay".
- [ ] App runs on owner's phone and appears in CarPlay. The phone app runs and streamed recitation on 2026-11-14. CarPlay was not opened during the afternoon membership recheck, so the icon was not seen on a car Home Screen.
- [x] Source permissions and catalog verification recorded. DESIGN.md §7 (2026-11-07) records the MP3Quran link permission. Streaming those links was heard on the phone on 2026-11-14. App Store redistribution and offline download remain out of scope.

## Official references

- [Requesting CarPlay entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)
- [Using the CarPlay Simulator](https://developer.apple.com/documentation/carplay/using-the-carplay-simulator)
- [CarPlay developer resources and additional tools](https://developer.apple.com/carplay/)
- [Running on simulated or physical devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
- [Enabling Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
