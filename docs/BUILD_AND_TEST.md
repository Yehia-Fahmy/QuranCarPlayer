# Build and test procedure

Two layers, two toolchains:

| Layer | Location | Needs | Command |
|---|---|---|---|
| Core logic (domain, catalog, playback rules, persistence, AVPlayer/Now Playing adapters) | `Packages/QuranCarPlayerCore` | Command Line Tools or Xcode | `Scripts/test-core.sh` |
| iOS app (SwiftUI phone UI, CarPlay scene, audio session) | `QuranCarPlayer.xcodeproj`, `App/`, `AppTests/` | Full Xcode with an iOS simulator runtime | `xcodebuild …` below |

## 1. Core package (works today on this Mac)

```sh
Scripts/test-core.sh
```

What it does: runs `swift test` for `QuranCarPlayerCore` on macOS. The package lists macOS
only so it can be tested without the iOS SDK; the app target is iOS-only.

Why a script: the Command Line Tools ship Swift Testing but do not resolve its macro plugin
automatically, so the script passes `-load-plugin-library …/libTestingMacros.dylib`. With
full Xcode selected, plain `swift test` in the package directory also works.

Expected result (November 6, 2026, Swift 6.4 CLT): `48 tests in 7 suites passed`.

Build only:

```sh
cd Packages/QuranCarPlayerCore && swift build
```

## 2. iOS app (Xcode 27.2 on this Mac)

### One-time
1. Install Xcode (Mac App Store or developer.apple.com), open it once, accept the license,
   install an iOS simulator runtime.
2. Either select it globally (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`)
   or export `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` per shell.
3. Record the versions in ENVIRONMENT.md:
   ```sh
   xcodebuild -version && xcrun swift --version && xcrun --sdk iphoneos --show-sdk-version
   ```

### Regenerate the project (only after editing `project.yml`)
```sh
brew install xcodegen      # already installed on this Mac: 2.46.0
Scripts/generate-project.sh
```
The generated `QuranCarPlayer.xcodeproj` is committed; opening it does not require XcodeGen.

### Build for the simulator
```sh
xcodebuild -list -project QuranCarPlayer.xcodeproj
xcodebuild -project QuranCarPlayer.xcodeproj -scheme QuranCarPlayer \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/QuranCarPlayer-DerivedData build
```

### Run app-bundle tests in a simulator
Verified 2026-11-07 on iPhone 17, iOS 27.2 (`6A7BEB9D-5E0D-455D-A67E-B920AFC202FE`): **TEST SUCCEEDED**, 5 tests.

```sh
xcodebuild -showdestinations -project QuranCarPlayer.xcodeproj -scheme QuranCarPlayer
xcodebuild -project QuranCarPlayer.xcodeproj -scheme QuranCarPlayer \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -derivedDataPath /tmp/QuranCarPlayer-DerivedData test
```
`AppTests/` checks the Info.plist scene manifest, background audio mode, bundled test tones,
localizations, and the composition root. `UITests/` (`PhonePlaybackUITests`) drives the phone
UI. Verified 2026-11-07: **3 tests passed** on the same iPhone 17 simulator. The scheme runs
both test targets. Core policy tests stay on `Scripts/test-core.sh`.

Phone UI tests pass `-QCPUITestReset`. `AppEnvironment` then uses in-memory stores so a
previous test's language or reciter does not leak. Do not pass that argument for a normal launch.

### CarPlay in the simulator
Apple's documented path (checked 2026-11-07): with the app running in the iOS simulator, choose **I/O ▸ External Displays ▸ CarPlay**. Xcode 27.2 does not ship `Simulator.app` at the old Developer/Applications path; DeviceHub (`Xcode.app/Contents/Applications/DeviceHub.app`) is the device UI. Record the exact successful menu path for this Xcode in ENVIRONMENT.md once the CarPlay window is opened. The CarPlay Simulator cannot establish real connection/auto-resume behaviour.

### Device builds
1. Copy `Config/Signing.xcconfig.example` to `Config/Signing.xcconfig` (gitignored) and set
   `QCP_DEVELOPMENT_TEAM` and a real `QCP_BUNDLE_ID`. This Mac already has a local file for
   Personal Team `FUT64434V9` (`yehia.fahmy@uwaterloo.ca`) and `com.yehiafahmy.QuranCarPlayerApp`.
2. Sign in under **Xcode ▸ Settings ▸ Accounts**. Without an account, device builds fail with
   "No Accounts" even when the team ID is set. That was the result on 2026-11-07 for
   Yehia's iPhone (`00008130-001C6C2C14DA001C`). On 2026-11-14 the app target built and
   installed with the existing Personal Team profile. A UI-test run still failed because
   `xcodebuild` could not create a profile for `com.yehiafahmy.QuranCarPlayer.uitests.xctrunner`.
3. Phone installs use `App/QuranCarPlayerPhone.entitlements` (empty), which is the default of
   `QCP_CODE_SIGN_ENTITLEMENTS`. `App/QuranCarPlayer.entitlements` still contains
   `com.apple.developer.carplay-audio`. Switch the setting to that file only after the paid
   team has the capability. A Personal Team cannot sign it.
4. Build and install:

```sh
xcodebuild -project QuranCarPlayer.xcodeproj -scheme QuranCarPlayer \
  -destination 'platform=iOS,id=DEVICE_UDID' \
  -allowProvisioningUpdates \
  -derivedDataPath /tmp/QuranCarPlayer-DeviceDD build
```

## 3. Test audio

`App/Resources/TestAudio/*.m4a` are synthetic beep tones generated by
`Scripts/generate-test-audio.py` (Python stdlib + macOS `afconvert`). They are test-owned
fixtures, labelled as such in the UI and Now Playing metadata, and are never Quran recitation.
Regenerate with:

```sh
python3 Scripts/generate-test-audio.py
```

## 4. Reporting rules

- A `swift test` pass on macOS verifies playback *policy*, not iOS audio behaviour.
- A simulator build is not a device-signing test. A missing entitlement or missing simulator
  runtime is a prerequisite failure, not an app failure; report it as such.
- Record simulator, physical-device, and in-car results separately in IMPLEMENTATION.md.
