# Feasibility notes: automatic CarPlay resume and surah-list position

Dated: November 6, 2026. Status: **documentation-level investigation only.** No CarPlay
Simulator, physical-device, or in-car test has been run yet because full Xcode is not
installed on the development Mac (see ENVIRONMENT.md). Every claim below is tagged with its
evidence level:

- **[API doc]** verified against Apple's current developer documentation on the date above.
- **[Implemented, unit-tested]** behaviour of the coordinator verified by `swift test` on macOS with a fake engine.
- **[Untested]** written but not compiled or exercised on iOS.
- **[Open]** needs a prototype run or an owner decision.

## 1. Automatic resume when CarPlay connects

### Confirmed requirement
The owner wants playback to start automatically on connection (DESIGN.md §2, §6). This is a
confirmed product desire with an explicit feasibility gate; it has not been changed.

### Apple guidance [API doc]
The CarPlay Human Interface Guidelines, "Audio" section, state: *"Let people choose when to
start playback. In general, avoid beginning playback automatically unless your app's purpose
is to play a single source of audio, or your app is resuming previously interrupted audio."*
and *"avoid starting an audio session until you're ready to actually play audio because
starting a session silences other audio sources, like the car's built-in radio."*

Reading: resuming the listener's own prior session is the kind of "resuming previously
interrupted audio" the guideline allows, provided the app does not silence the car radio
before it is ready and does not start arbitrary new content. Auto-starting with no saved
session, or after the session completed at An-Nas, is not covered by the exception and the
app does not do it. App Review applies these guidelines; a reviewer may still object. That
risk cannot be removed by code and should be weighed before public release.

### Lifecycle facts [API doc]
- The CarPlay scene delegate receives `templateApplicationScene(_:didConnect:)` when the
  scene connects and `templateApplicationScene(_:didDisconnectInterfaceController:)` when it
  disconnects. The app process is launched (or woken) by the system to deliver the scene when
  the car connects and the app is a CarPlay app.
- A CarPlay connection, a scene connection, and an audio route becoming available are
  separate events. Apple does not document a guarantee that a background-launched CarPlay
  scene may begin audio without a user gesture in every lifecycle state.

### What is implemented [Implemented, unit-tested]
`PlaybackCoordinator.carPlayDidConnect()` evaluates `evaluateAutomaticResume()` and resumes
at most once per connection when all of these hold:

1. The phone setting "Resume automatically when CarPlay connects" is on (default on).
2. A current recording exists and the session is not completed, failed, or already active.
3. The last pause was **not** a deliberate user pause (`PauseReason.user`). Pauses caused by
   car disconnection, route loss, or a system interruption are eligible.

`carPlayDidDisconnect()` pauses, saves the checkpoint with `lastPauseReason = .carDisconnected`,
and cancels any pending retry. The pause reason is persisted so the decision survives relaunch.
Unit tests cover: resume once per connection; no resume on first use, completed session,
disabled setting, deliberate pause, or while already playing; disconnect pauses and the next
connect resumes at the saved position.

### What is not known [Open]
The prototype matrix from DESIGN.md §6 must be run in a real car and recorded here:

| Case | Result |
|---|---|
| App already running in foreground | not tested |
| App backgrounded | not tested |
| App not running (never launched since reboot) | not tested |
| App manually force-quit by user | not tested |
| Phone locked | not tested |
| Wired vs. wireless CarPlay | not tested |
| Previously playing when car turned off | not tested |
| Previously paused by user | policy implemented as "do not resume"; owner decision pending |
| Another audio app playing at connection | not tested; policy open |
| No saved session | implemented: never starts audio (unit-tested) |

Two policy questions are deliberately left for the owner after the prototype:
- **Manually paused session.** Current default: do not auto-resume. Alternative: resume anyway
  because the car disconnecting is the natural "end of journey" signal. One-line change in
  `evaluateAutomaticResume()`.
- **Another app is playing.** Current default: no special handling (the system will interrupt
  the other app when our session activates). Alternative: skip auto-resume when another
  session is active (`AVAudioSession.secondaryAudioShouldBeSilencedHint` or
  `isOtherAudioPlaying`), which keeps the car radio or a podcast playing.

### Recommended next step
Install Xcode, run on the owner's phone, and drive the matrix above. Log lines prefixed
`[CarPlay]` (see `CarPlaySceneDelegate`) print the auto-resume decision on each connection.

## 2. Surah-list position on CarPlay

### Confirmed requirement
Remember list position, or open at the current surah, on both surfaces (DESIGN.md §2).

### Findings [API doc]
`CPListTemplate` exposes `sections`, `updateSections(_:)`, `indexPath(for:)`, `itemCount`,
`maximumItemCount`, `maximumSectionCount`, `emptyViewTitleVariants`, and delegate callbacks.
Its documented API surface contains **no method to scroll to, select, or reveal a row**, and
no way to read the current scroll offset. `CPListItem` has `isPlaying` and
`playingIndicatorLocation` for the native Now Playing indicator, and `setText(_:)` /
`setDetailText(_:)` / `setAccessoryImage(_:)` for in-place updates.

Conclusion: **exact scroll restoration or programmatic positioning of the CarPlay surah list
is not possible with public API** as documented today. This is a platform limitation, not a
design choice, and the requirement has not been changed.

### What is implemented [Untested]
- Template and `CPListItem` instances are created once per connection and kept
  (`CarPlayTemplateController`). State changes update items in place (`isPlaying`, text) and
  only call `updateSections` when the header (selected reciter) or language changes. Whether
  `updateSections` resets the scroll position is unknown and must be observed in the
  prototype.
- The current surah is marked with the native playing indicator so it is visually findable.
- `CPListTemplate.maximumItemCount` is read at connection time and logged. If it is below 114
  the list is limited to that count **and** an alert tells the user; the limit is never
  applied silently.

### Proposed fallback for owner review [Open]
If the prototype confirms that returning to the Surahs tab resets scrolling, DESIGN.md's
proposed fallback is a clearly labelled "Current surah" shortcut above the full list on the
Listen tab (the "Now Playing" row already serves this on the Listen tab). The Quran order of
the Surahs list is preserved. This shortcut does **not** satisfy exact scroll restoration and
must not be reported as if it does.

### Phone [Untested]
The SwiftUI list uses `ScrollViewReader.scrollTo(anchor)` with a stable surah number
(`AppSettings.surahListAnchor`, falling back to the current surah). No pixel offset is stored.

## 3. Other CarPlay facts gathered [API doc]

- Tab bar: `CPTabBarTemplate.maximumTabCount` depends on the app's entitlements; read at
  runtime. The design's three tabs (Listen, Surahs, Reciters) fit typical audio-app limits
  but this is verified only at runtime (logged).
- `CPListItem.handler` must call its completion; CarPlay shows a spinner until it does. The
  controller completes the callback when the selection is playing, paused, failed, or
  replaced, with a 30-second safety timeout.
- `CPNowPlayingTemplate.shared` is pushed when audio is ready to play (HIG: "Display the Now
  Playing screen when audio is ready to play"). Up Next and Album-Artist buttons are disabled.
- `CPAlertTemplate` is used for load failures with a Retry action so recovery never requires
  the phone (HIG: "Report errors in CarPlay, not on the connected iPhone").
- `CPTabBarTemplate.select(_:)` / `selectTemplate(at:)` are iOS 17+, matching the provisional
  deployment target.

## Sources (read November 6, 2026)

- https://developer.apple.com/design/human-interface-guidelines/carplay
- https://developer.apple.com/documentation/carplay/cplisttemplate
- https://developer.apple.com/documentation/carplay/cplistitem
- https://developer.apple.com/documentation/carplay/cptabbartemplate
- https://developer.apple.com/documentation/carplay/cpnowplayingtemplate
- https://developer.apple.com/documentation/carplay/cptemplateapplicationscenedelegate
- https://developer.apple.com/documentation/carplay/displaying-content-in-carplay
- https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements
