# Implementation milestones and acceptance checks

Read DESIGN.md and ENVIRONMENT.md first. Work in small reviewable changes. Check off work only with evidence; these tasks are all pending. Keep confirmed product requirements separate from defaults and platform limitations. Update these documents as decisions are resolved.

Legend for evidence tags used below: **[macOS-tested]** verified by `Scripts/test-core.sh`; **[simulator-built]** compiled for iOS Simulator; **[simulator-tested]** ran in iPhone 17 simulator; **[blocked]** waiting on the owner or on hardware.

## Milestone 0 — Toolchain and feasibility

- [x] Establish the Xcode toolchain, app project, shared scheme, simulator, and device signing.
  - [x] App project, shared scheme, entitlements, Info.plist scene manifest, signing xcconfig mechanism.
  - [x] Xcode 27.2 (27B52), iOS SDK 27.2, iOS Simulator runtime 27.2 (24B8117). Simulator **build succeeded**; **5/5 app tests passed** on iPhone 17 (2026-11-07).
  - [x] Device signing **[device, 2026-11-14]**. Personal Team `MN7YP2FD68` has an Apple Development certificate. `xcodebuild` for iPhone 15 Pro Max (`00008130-001C6C2C14DA001C`, iOS 27.0.1) **BUILD SUCCEEDED**, and the app installed as `com.yehiafahmy.QuranCarPlayer` 0.1.0. Phone builds still use `App/QuranCarPlayerPhone.entitlements`. Xcode lists only this free Personal Team. Creating a new UI-test profile still fails with "No Account for Team MN7YP2FD68"; the app signed with the existing profile, which expires the same day.
- [ ] Verify/request CarPlay audio entitlement through the owner's account. **[blocked: owner]** Instructions in ENVIRONMENT.md "Owner actions".
- [ ] Build a small native CarPlay list and Now Playing prototype with test-owned audio.
  - [x] Written and **[simulator-built]**: `CarPlaySceneDelegate`, `CarPlayTemplateController`, test tones bundled. App-bundle test confirms the CarPlay scene delegate class resolves at runtime.
  - [ ] Shown in CarPlay Simulator (I/O ▸ External Displays ▸ CarPlay not yet opened on this Mac).
- [ ] Test 114-item browsing, native playing indicators, returning to a list, tab switching, reconnecting, and list-position restoration using public APIs. **Documentation finding (FEASIBILITY.md §2): no public scroll/position API on `CPListTemplate`.** Runtime behaviour untested.
- [ ] Test automatic resume in all lifecycle cases listed in DESIGN.md. Resolve the manually-paused-session and other-audio-app policies with the owner using findings. Policy implemented and unit-tested (FEASIBILITY.md §1) **[macOS-tested]**; in-car matrix **[blocked: Xcode, device, car]**; two owner decisions open.
- [x] Verify production audio provider permissions, attribution, and the four candidate recording collections. **2026-11-07:** MP3Quran v3 returned complete Hafs murattal collections for Maher Al-Muaiqly (moshaf 102), Mishary Rashid Alafasy (123), Abdul Rahman Al-Sudais (54), and Saud Al-Shuraim (31). Their copyright note allows use of site links. The app streams those URLs and shows attribution in Settings. Offline download and App Store redistribution are still not covered by that note. See DESIGN.md §7.

Deliverable: reproducible prototype and a dated feasibility note with device/SDK details, actual results, limitations, and owner decisions. Do not wait for entitlement or source approval to implement independent domain logic and phone functionality with fixtures. → `docs/FEASIBILITY.md` (dated 2026-11-06, documentation-level; device results pending).

## Milestone 1 — Catalog and playback foundation

- [x] Define stable surah, reciter, collection, recording, and session IDs. `Surah`, `ReciterID`, `RecordingCollectionID`, `RecordingID`, `PlaybackSession`, `SessionCheckpoint` (versioned) **[macOS-tested]**.
- [x] Add bilingual surah metadata; validate exactly 114 unique sequential IDs. `surahs.json` + `SurahCatalog` validation **[macOS-tested]**. **Caveat:** names were entered from general knowledge, not imported from a verified permitted source; an owner/agent must proofread all 114 Arabic names and transliterations before release.
- [x] Implement provider adapter and last-known-good catalog cache with fixture tests. `MP3QuranCatalog` loads `mp3quran-catalog.json` (snapshot retrieved 2026-11-07) and builds HTTPS URLs from the stored server. `FixtureAudioCatalog` remains for unit tests and UI tests (`-QCPUITestReset`). A saved session whose collection is not in the current catalog is discarded on launch.
- [x] Build shared playback coordinator, intent-aware state transitions, retry cancellation, and stale-operation rejection. `PlaybackCoordinator` **[macOS-tested]**: scenarios 1–7, 13–17 covered by unit tests.
- [x] Implement continuous ordered playback, next/previous boundaries, reciter changes, checkpoint restore, and completed-session handling **[macOS-tested]**.
- [ ] Add audio-session handling, background playback, Now Playing metadata, and remote commands. `AVPlayerEngine`, `NowPlayingBridge`, `AudioSessionController` **[simulator-built]**. Background audio mode declared and asserted by an app test. Foreground streaming **[device, 2026-11-14]**: Al-Fatihah moved from 0:05 to 0:27 of 0:38, then advanced to Al-Baqarah (duration 1:47:59); pause held at 0:32. Lock screen, background, and remote commands are still untested.

Exit: playback works on the phone while locked, state survives a relaunch, controls act on one shared session, and policy tests pass without network access. → Policy tests pass without network **[macOS-tested]**. Foreground play, natural advance, and pause work on the phone **[device, 2026-11-14]**. Locked-phone playback and relaunch-after-streaming are still open.

## Milestone 2 — Phone interface

- [x] Surah list, reciter selection, player, and settings. **[simulator-tested]** by `PhonePlaybackUITests` (2026-11-07): list reaches surah 114, selecting surah 1 starts test-tone playback, pause works, Next moves to surah 2, reciter change updates the header, Settings switches the UI to Arabic. Saved list-anchor restore is implemented; the UI tests reset storage, so anchor restore was not the thing those tests checked. **[device, 2026-11-14]**: launch restored An-Nisa paused under Maher Al-Muaiqly; tapping surah 1 opened Now Playing with no test-audio banner. Reciter change and Arabic were not repeated on the phone.
- [x] System/English/Arabic localization. **[simulator-tested]** by the settings UI test (Arabic title "الإعدادات", list title "السور"). Right-to-left layout is set from the language but was not inspected visually.
- [ ] Loading, buffering, retry, first-use, and completed-session states. Status text and Retry present in `PlayerView` **[simulator-built]**.
- [ ] Dynamic Type and VoiceOver checks on key controls and bilingual names. Labels added; not checked on a device.

Exit: a new user can select a surah, change reciter, pause, resume, seek, and change language; no account is required.

## Milestone 3 — CarPlay interface

- [ ] Native Listen / Surahs / Reciters templates and native Now Playing. **[simulator-built]**; not shown in CarPlay Simulator.
- [ ] Shared state synchronization across phone, car, and remote controls. One coordinator in `AppEnvironment.shared` **[simulator-tested]** by composition-root test. Car/remote surfaces untested.
- [ ] Implement proven list-position behavior; obtain owner agreement for any fallback. See FEASIBILITY.md §2; owner decision pending after prototype.
- [ ] Implement validated automatic resume policy and car-disconnection pause. Policy **[macOS-tested]**; validation in car pending.
- [ ] Handle scene reconnects, selection callbacks, loading cancellation, language rebuilds, and errors without losing playback position. Selection completion/timeout, in-place relocalization, failure alert **[simulator-built]**.

Exit: ordinary listening works with the phone locked. Every confirmed behavior works or has a documented platform limitation and an owner-approved alternative.

## Milestone 4 — Reliability and release preparation

- [ ] Run the acceptance scenarios below and record pass/fail evidence.
- [ ] Test long recordings and transitions on real network conditions and the owner's car.
- [ ] Verify catalog completeness, metadata accuracy, source rights, and attribution.
- [ ] Add app icon/branding, support information, privacy policy and actual App Store disclosures.
- [ ] Prepare TestFlight build and CarPlay review notes with entitlement/signing evidence.
- [ ] Obtain the owner's direction before distribution or App Store submission.

## Behavior acceptance scenarios

### Selection and transport

1. Select surah 18 while Maher is selected: start surah 18 at zero, show matching metadata on phone and CarPlay.
2. Change to another reciter while playing: restart surah 18 at zero with that recording; no old audio or callbacks can overwrite the new selection.
3. Change reciter while paused: reset the current surah to zero and remain paused (proposed default).
4. Select the current surah from the list: restart from zero; Continue Listening instead resumes saved position.
5. Natural end of 18: play 19 exactly once, same reciter, without added delay. Natural end of 114: stop and persist completion.
6. Previous at >3 seconds restarts; at <=3 seconds moves back; at surah 1 restarts 1. Next at 114 does not wrap.
7. Rapid surah/reciter taps, an end event during a tap, and a late network completion cannot create duplicate playback or the wrong queue.

### Resume and connection

8. Pause at a known timestamp, relaunch, and choose Continue Listening: restore the exact recording and position within the checkpoint/seek tolerance. Record the measured tolerance; aim for about two seconds after an explicit pause and no more than the periodic checkpoint interval after a crash.
9. Connect CarPlay with an eligible saved session: automatic resume follows the documented prototype-supported policy and occurs at most once per connection.
10. First use and completed-114 session: no arbitrary automatic recording begins.
11. Disconnect car while playing or retrying: pause, save, cancel retry, and do not play through the phone speaker.
12. Test phone locked, app backgrounded, cold launch, force-quit, wired/wireless when available, and competing audio. Record unsupported cases honestly.

### Interruptions and network

13. Call/Siri/navigation interruption: behavior follows platform signals; a deliberate pause prevents unexpected resumption.
14. Lose connectivity mid-surah: retain item/position, retry within policy, then offer Retry. Never skip or substitute content.
15. Retry after connection returns: resume the same recording. Pause or selection during recovery cancels the old operation.
16. Missing file/invalid URL/provider failure: localized recoverable message, no crash, endless spinner, or unbounded retry.
17. Unavailable next surah: stop with context and Retry instead of skipping it.

### Browsing and presentation

18. All 114 surahs remain accessible in Quran order in both languages; no truncation or accidental grouping.
19. Return to Surahs: restore the validated position behavior. Check tab switching, Now Playing return, reconnect, and language change separately.
20. English/Arabic/system language changes update both surfaces and metadata without restarting playback. Validate Arabic right-to-left layout and readable names on the actual head unit.
21. Phone, lock-screen, steering-wheel, and CarPlay controls produce consistent state and metadata. Unknown duration does not show fabricated progress.

## Testing strategy

Unit-test policy boundaries, queue progression, persistence, retry cancellation, stale callbacks, and catalog decoding with fixtures and an injected clock. Add a few UI tests for phone selection and settings. Use simulator/manual CarPlay checks for templates and physical-device checks for route, lifecycle, and audio behavior. Avoid making network availability a prerequisite for every test run.

For each implementation handoff, record changed files, commands run, results, manual device evidence, known limitations, and the next unblocked milestone. Do not claim a build or test was run if prerequisites prevented it.

## Open: CarPlay (future agent)

Leave these until the paid Developer Program membership is active and Apple has attached CarPlay Audio to the App ID. Do not delete the CarPlay source to make the phone build succeed.

- Switch `QCP_CODE_SIGN_ENTITLEMENTS` from `App/QuranCarPlayerPhone.entitlements` (current, empty) to `App/QuranCarPlayer.entitlements` (`com.apple.developer.carplay-audio`). Adding the Boolean does not grant the capability.
- Install the signed app on the iPhone and confirm the icon appears in CarPlay Simulator. On this Mac, Xcode 27 uses Device Hub with the physical iPhone over USB (window title like "Yehia's iPhone / Standard"). The old Simulator menu I/O ▸ External Displays ▸ CarPlay is not the path that worked here. A car Home Screen was seen on 2026-11-07; QuranCarPlayer was absent because it was not installed and a free Personal Team cannot sign the CarPlay entitlement.
- Run the in-car automatic-resume matrix (FEASIBILITY.md §1). Policy is unit-tested only. Two owner decisions remain: resume after a deliberate pause, and whether to skip resume when another app is playing.
- List position: current `CPListTemplate` docs have no scroll API. Exact restoration is not possible with the public API. Any shortcut (for example a labelled Current Surah row) needs owner approval. Do not reorder the Quran list.
- Lock screen, steering-wheel, and background audio on a real device are untested.

## Handoff record

### 2026-11-06 — Milestone 0 foundation (branch `codex/milestone-0-foundation`)

**Added**
- `Packages/QuranCarPlayerCore/` — SwiftPM package: `Domain/` (Surah, Reciter, RecordingID, PlaybackSession, AppSettings, Language), `Catalog/` (SurahCatalog + `surahs.json`, AudioCatalog protocol, FixtureAudioCatalog), `Playback/` (AudioEngine protocol, Scheduling/RetryPolicy, PlaybackState, PlaybackCoordinator), `Playback/Platform/` (AVPlayerEngine, NowPlayingBridge, AudioSessionController), `Persistence/` (file/UserDefaults/in-memory stores). Tests in `Tests/QuranCarPlayerCoreTests/`.
- `App/` — iOS app sources (SwiftUI phone UI, CarPlay scene + template controller, composition root, localization), `Info.plist`, entitlements, `Assets.xcassets` placeholders, `Localizable.xcstrings`, `Resources/TestAudio/*.m4a`.
- `AppTests/` — app-bundle smoke tests (Swift Testing; run only via Xcode).
- `project.yml`, `QuranCarPlayer.xcodeproj` (generated, shared scheme), `Config/Shared.xcconfig`, `Config/Signing.xcconfig.example`, `Scripts/` (`test-core.sh`, `generate-project.sh`, `generate-test-audio.py`), `.gitignore`.
- `docs/FEASIBILITY.md`, `docs/BUILD_AND_TEST.md`; updates to `ENVIRONMENT.md`, this file, `README.md`.

**Commands run and results**
- `Scripts/test-core.sh` → `48 tests in 7 suites passed` (macOS 27.0.1, Swift 6.4 CLT). Covers acceptance scenarios 1–11 (policy level), 13–17, plus persistence and catalog validation.
- `swift build` in the package → clean, no warnings (includes AVPlayerEngine/NowPlayingBridge on macOS).
- `swiftc -parse` on every file in `App/Sources` and `AppTests` → no syntax errors. **Not type-checked, not built.**
- `Scripts/generate-project.sh` → project generated; pbxproj inspected for package link, resources, entitlements, scheme.
- `xcodebuild` → **not run** (Xcode not installed).

**Manual device evidence:** none. No simulator, phone, or car test has happened.

**Known limitations / risks**
- The iOS target has never been compiled. Expect some compile fixes when Xcode is available, particularly around SwiftUI API availability and CarPlay closure isolation. Core logic is isolated from this risk and is tested.
- Surah names need proofreading against a trusted source (114 entries in `surahs.json`).
- Test tones only. No Quran audio, no provider adapter, no attribution text for a real source.
- No public CarPlay API for list scroll restoration (FEASIBILITY.md §2). Owner decision on fallback pending prototype.
- Auto-resume: two open owner decisions (manually paused session; other app playing). In-car matrix not run.
- SwiftUI `App` lifecycle plus a CarPlay scene declared only in Info.plist is a common pattern but is unverified here; if the CarPlay scene does not connect, add an `AppDelegate` implementing `application(_:configurationForConnecting:options:)` that returns the CarPlay configuration for `.carTemplateApplication`.
- `AudioSessionController` uses `.playback` / `.default` mode; `.spokenAudio` was considered and left as a later decision.
- App icon and CarPlay icon slots are empty placeholders.

**Next concrete tasks (in order)**
1. Agent/owner: in the iOS Simulator GUI, open **I/O ▸ External Displays ▸ CarPlay** and record: tab bar, 114 items / `maximumItemCount`, playing indicator, Now Playing push, Retry alert, whether returning to Surahs preserves scroll. Update FEASIBILITY.md §2. Xcode 27.2 ships DeviceHub (`com.apple.dt.Devices`) rather than the legacy `Simulator.app` path.
2. Owner: set `Config/Signing.xcconfig` (Team ID + real bundle ID) and request the CarPlay audio entitlement (ENVIRONMENT.md "Owner actions" items 3–4).
3. Agent (needs device + entitlement): run on the phone, verify lock-screen controls and background audio with test tones; then the in-car auto-resume matrix (FEASIBILITY.md §1).
4. Owner + agent: resolve the two auto-resume policy decisions and the list-position fallback.
5. Separately: production audio permission review (DESIGN.md §7) before any provider adapter is written.

### 2026-11-07 — Simulator toolchain unblocked

**Changed:** `AppEnvironment.fixtureNames` marked `nonisolated` (fixes a Swift 6 concurrency warning in AppTests). Docs updated.

**Commands run and results**
- `xcodebuild … -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build` → **BUILD SUCCEEDED**, zero compiler warnings (AppIntents metadata skip is Xcode noise).
- `xcodebuild … -destination 'platform=iOS Simulator,id=6A7BEB9D-5E0D-455D-A67E-B920AFC202FE' test` → **TEST SUCCEEDED**, 5/5 app-bundle tests.
- `xcrun simctl install` + `launch` on iPhone 17 → app launched. Screenshot: Surahs list, test-tone reciter labelled as not Quran.

**Manual device evidence:** none (no physical iPhone connected).

**CarPlay Simulator:** not opened in that session. Apple's current docs still specify Simulator **I/O ▸ External Displays ▸ CarPlay** after a simulator run. Later the same day a car Home Screen was shown via Device Hub attached to the physical iPhone; see the next handoff.

### 2026-11-07 — Phone UI verified; device install blocked on Accounts

**Changed**
- Default device signing uses `App/QuranCarPlayerPhone.entitlements` via `QCP_CODE_SIGN_ENTITLEMENTS`. `App/QuranCarPlayer.entitlements` stays in the repo for the future CarPlay switch.
- `UITests/PhonePlaybackUITests.swift`. Launch argument `-QCPUITestReset` makes `AppEnvironment` use in-memory session and settings stores so tests do not leak language or reciter.
- Play/pause and the test-audio banner have accessibility identifiers.

**Commands run and results**
- `xcodebuild … -destination 'platform=iOS Simulator,id=6A7BEB9D-5E0D-455D-A67E-B920AFC202FE' -only-testing:QuranCarPlayerUITests test` → **TEST SUCCEEDED**. Three tests: surah list through 114, player play/pause and next surah, reciter change and Arabic settings. Each launch is isolated.
- `xcodebuild … -destination 'platform=iOS,id=00008130-001C6C2C14DA001C' -allowProvisioningUpdates build` → **BUILD FAILED**: "No Accounts" and no profile for `com.yehiafahmy.QuranCarPlayer`. Same result from Xcode's provisioning update after the project was opened. Team ID in the local xcconfig is `MN7YP2FD68`; Xcode reports that team with a null name because no Apple ID is signed in.

**Manual device evidence:** Yehia's iPhone 15 Pro Max (`00008130-001C6C2C14DA001C`, iOS 27.0.1) is paired, available, and Developer Mode is on. The app was not installed. Xcode's run destination is that phone. The one step only the owner can do: Xcode ▸ Settings ▸ Accounts, sign in with the Apple ID for Personal Team `MN7YP2FD68`, then build again. The first install may ask to trust the developer under Settings ▸ General ▸ VPN & Device Management.

**Next concrete tasks**
1. Owner: sign in to Xcode Accounts. Agent: device build, install, launch, and confirm the test-tone banner and play/pause on the phone.
2. Future agent, after paid membership and CarPlay entitlement: the "Open: CarPlay" list above.
3. Still separate: proofread `surahs.json`, and do not add a production audio provider until DESIGN.md §7 permission is recorded.

### 2026-11-14 — Phone streaming heard on the owner's iPhone

**Changed:** documentation only. No application source changed. The working tree was clean before this note.

**Commands run and results**
- `xcodebuild … -destination 'platform=iOS,id=00008130-001C6C2C14DA001C' -allowProvisioningUpdates build` → **BUILD SUCCEEDED**. Signed with Apple Development `yehiafahmy@icloud.com` and the existing profile `e0478bbd-074c-40f6-811d-ab5b835eb4a1` (Personal Team `MN7YP2FD68`).
- `devicectl device install app` → installed `com.yehiafahmy.QuranCarPlayer` 0.1.0. `devicectl device process launch` opened it.
- `xcodebuild test` for `QuranCarPlayerUITests` on the phone → **TEST FAILED** before the test ran: "No Account for Team MN7YP2FD68" and no profile for `com.yehiafahmy.QuranCarPlayer.uitests.xctrunner`. The app target did not need a new profile.

**Manual device evidence:** iPhone 15 Pro Max, iOS 27.0.1, unlocked, USB. Launch showed Surahs, "Reciter: Maher Al-Muaiqly", surah 4 marked with the speaker icon, and a mini player "4. An-Nisa / Paused". Tapping surah 1 opened Now Playing: "1. Al-Fatihah", "The Opening", "Maher Al-Muaiqly", status Playing, elapsed 0:05 of 0:38, pause control visible, no test-audio banner. A later capture showed 0:27 of 0:38. The next capture was "2. Al-Baqarah", "The Cow", duration 1:47:59, then Paused at 0:04 and later at 0:32. Left paused on Al-Baqarah. Lock screen, background (a home swipe did not leave the player), airplane mode, reciter change, and Arabic layout were not exercised. Xcode still shows only the free Personal Team, so CarPlay signing is unchanged.

**Known limitations**
- Free-team profiles created 2026-11-07 expire 2026-11-14. The installed app can stop launching until it is signed again.
- Command-line provisioning cannot create a new profile until Xcode's account session is available to `xcodebuild`.
- A paid Developer Program team is still absent from Xcode. CarPlay stays blocked on that, then on Apple's entitlement approval.

**Next concrete tasks**
1. Confirm whether the paid membership is active. If a second team appears in Xcode Settings ▸ Accounts, register the bundle ID there and request CarPlay Audio.
2. On the phone: lock-screen controls, background playback, and Retry after the network drops.
3. Proofread `surahs.json` before anyone else uses the app.
