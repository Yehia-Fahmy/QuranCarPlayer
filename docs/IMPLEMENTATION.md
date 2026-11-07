# Implementation milestones and acceptance checks

Read DESIGN.md and ENVIRONMENT.md first. Work in small reviewable changes. Check off work only with evidence; these tasks are all pending. Keep confirmed product requirements separate from defaults and platform limitations. Update these documents as decisions are resolved.

Legend for evidence tags used below: **[macOS-tested]** verified by `Scripts/test-core.sh`; **[simulator-built]** compiled for iOS Simulator; **[simulator-tested]** ran in iPhone 17 simulator; **[blocked]** waiting on the owner or on hardware.

## Milestone 0 — Toolchain and feasibility

- [ ] Establish the Xcode toolchain, app project, shared scheme, simulator, and device signing.
  - [x] App project, shared scheme, entitlements, Info.plist scene manifest, signing xcconfig mechanism.
  - [x] Xcode 27.2 (27B52), iOS SDK 27.2, iOS Simulator runtime 27.2 (24B8117). Simulator **build succeeded**; **5/5 app tests passed** on iPhone 17 (2026-11-07).
  - [ ] Device signing **[blocked: team/bundle ID + entitlement]**.
- [ ] Verify/request CarPlay audio entitlement through the owner's account. **[blocked: owner]** Instructions in ENVIRONMENT.md "Owner actions".
- [ ] Build a small native CarPlay list and Now Playing prototype with test-owned audio.
  - [x] Written and **[simulator-built]**: `CarPlaySceneDelegate`, `CarPlayTemplateController`, test tones bundled. App-bundle test confirms the CarPlay scene delegate class resolves at runtime.
  - [ ] Shown in CarPlay Simulator (I/O ▸ External Displays ▸ CarPlay not yet opened on this Mac).
- [ ] Test 114-item browsing, native playing indicators, returning to a list, tab switching, reconnecting, and list-position restoration using public APIs. **Documentation finding (FEASIBILITY.md §2): no public scroll/position API on `CPListTemplate`.** Runtime behaviour untested.
- [ ] Test automatic resume in all lifecycle cases listed in DESIGN.md. Resolve the manually-paused-session and other-audio-app policies with the owner using findings. Policy implemented and unit-tested (FEASIBILITY.md §1) **[macOS-tested]**; in-car matrix **[blocked: Xcode, device, car]**; two owner decisions open.
- [ ] Verify production audio provider permissions, attribution, and the four candidate recording collections. Document evidence and any unavailable reciter. Not started; the app ships test tones labelled as such.

Deliverable: reproducible prototype and a dated feasibility note with device/SDK details, actual results, limitations, and owner decisions. Do not wait for entitlement or source approval to implement independent domain logic and phone functionality with fixtures. → `docs/FEASIBILITY.md` (dated 2026-11-06, documentation-level; device results pending).

## Milestone 1 — Catalog and playback foundation

- [x] Define stable surah, reciter, collection, recording, and session IDs. `Surah`, `ReciterID`, `RecordingCollectionID`, `RecordingID`, `PlaybackSession`, `SessionCheckpoint` (versioned) **[macOS-tested]**.
- [x] Add bilingual surah metadata; validate exactly 114 unique sequential IDs. `surahs.json` + `SurahCatalog` validation **[macOS-tested]**. **Caveat:** names were entered from general knowledge, not imported from a verified permitted source; an owner/agent must proofread all 114 Arabic names and transliterations before release.
- [ ] Implement provider adapter and last-known-good catalog cache with fixture tests. Only `FixtureAudioCatalog` exists (test tones). Production adapter blocked on source permission.
- [x] Build shared playback coordinator, intent-aware state transitions, retry cancellation, and stale-operation rejection. `PlaybackCoordinator` **[macOS-tested]**: scenarios 1–7, 13–17 covered by unit tests.
- [x] Implement continuous ordered playback, next/previous boundaries, reciter changes, checkpoint restore, and completed-session handling **[macOS-tested]**.
- [ ] Add audio-session handling, background playback, Now Playing metadata, and remote commands. `AVPlayerEngine`, `NowPlayingBridge`, `AudioSessionController` **[simulator-built]**. Background audio mode declared and asserted by an app test. Not exercised on a device or with lock-screen controls.

Exit: playback works on the phone while locked, state survives a relaunch, controls act on one shared session, and policy tests pass without network access. → Policy tests pass without network **[macOS-tested]**; the rest is untested.

## Milestone 2 — Phone interface

- [ ] Surah list, saved visible anchor/current-surah positioning, reciter selection, player, and settings. **[simulator-built]**; first-launch Surahs list **[simulator-tested]** by screenshot (Quran order, test-tone reciter labelled). Playback, reciter sheet, and settings not tapped.
- [ ] System/English/Arabic localization and right-to-left layout. **[simulator-built]**; en/ar string resolution **[simulator-tested]** by app test. RTL not visually checked.
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

**CarPlay Simulator:** not opened. Apple's current docs still specify Simulator **I/O ▸ External Displays ▸ CarPlay** after a simulator run.
