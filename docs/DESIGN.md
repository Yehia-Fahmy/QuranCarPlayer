# Product and technical design

Status: implementation-ready direction with explicit feasibility gates. No implementation or device testing has occurred. Decisions below reflect the design conversation on November 6, 2026. Proposed defaults are agent recommendations, not additional user commitments.

## 1. Purpose

Make it frictionless to choose a Quran surah and reciter from CarPlay, listen continuously, and resume on the next journey. The owner has minimal Swift experience and wants future agents to implement this plan. The initial audience is the owner; eventual distribution is a free App Store app. The owner has an iPhone, a CarPlay-equipped car, and Apple Developer Program membership.

Success means a user can perform ordinary listening tasks with the phone locked and without needing to open the phone app during a drive.

## 2. Confirmed scope

- A functional iPhone player and a CarPlay interface sharing one listening session.
- Streaming first; optional downloads later.
- All 114 surahs, in Quran order, in a simple list. No favorites or recently played list.
- Remember list position, or open at the current surah. Platform feasibility must be established for CarPlay.
- Remember the selected reciter. Tapping a surah plays immediately with that reciter, from the beginning.
- Changing reciters restarts the current surah with the new reciter. Do not carry timestamps across recordings.
- Automatically play the next surah with the same reciter. Stop after An-Nas (114); do not loop.
- Save surah, reciter, and timestamp for Continue Listening.
- Desired behavior: automatically resume audio when connecting to CarPlay. See the feasibility gate below.
- On car disconnection, pause and save position.
- Next skips to the next surah. Previous restarts the current surah when more than three seconds in; otherwise it goes to the previous surah.
- Briefly retry interrupted streaming; retain position and offer Retry if recovery fails. Never silently skip surahs or substitute reciters.
- System / English / العربية language setting, initially following the phone. Apply to phone and CarPlay, including names. Arabic uses right-to-left layout.
- Listening only. Quran text, translations, memorization, verse repeat, Siri selection, downloads, and custom playlists are outside v1.

## 3. Proposed defaults to make implementation concrete

These can be refined without reopening the core product concept:

- Working app name: QuranCarPlayer; final branding remains open.
- Default reciter: Maher Al-Muaiqly (ماهر المعيقلي).
- Candidate additional reciters: Mishary Rashid Alafasy (مشاري العفاسي), Abdul Rahman Al-Sudais (عبد الرحمن السديس), and Saud Al-Shuraim (سعود الشريم). Inclusion depends on complete, permitted recordings; this is a curated shortlist, not a verified popularity ranking.
- Use one complete Hafs an Asim recording collection per reciter initially. Verify collection identity and all 114 recordings. Do not mix riwayat or collections implicitly.
- No accounts, ads, payments, analytics SDK, cloud sync, or custom backend for v1. Free distribution does not itself settle audio usage rights.
- Provisional deployment target: iOS 17+, subject to the owner's phone and actual SDK compatibility. Build with a stable Xcode version supported by the development Mac; record exact versions once installed.
- First use with no saved session does not start arbitrary audio. Present the surah list and Maher as selected reciter.
- Expose automatic CarPlay resume as a phone setting, with the desired enabled state explained in initial setup; final policy depends on prototype and Apple guidance.
- No intentionally added silence or crossfade between surahs. Do not promise sample-accurate gapless playback for remote files.
- Basic phone seeking is supported; CarPlay uses available native controls rather than a custom scrubber.
- At surah 1, Previous restarts surah 1. At surah 114, Next is disabled where supported and otherwise a no-op.
- At the end of 114, mark the session completed. Reconnecting does not loop or restart it; explicit play can restart 114, and choosing another surah creates a new session.
- Reciter changes while paused update the current surah to time zero and leave it paused; changes while playing restart playback. With no current surah, changing reciter only changes the selection. Selecting the already-selected reciter is a no-op.

## 4. Screen flows

### CarPlay

Use Apple's native CarPlay templates. Proposed root: a `CPTabBarTemplate` with Listen, Surahs, and Reciters. Validate template availability and tab limits against the selected SDK and audio entitlement.

**Listen:** Continue Listening showing the saved surah and reciter when a resumable session exists; access to Now Playing when an item is loaded. On first launch show a useful Choose a Surah action instead of an empty resume row. Do not add a listening-history list.

**Surahs:** numbered 1–114, localized name, selected reciter identified in the screen context. Mark the active item with the native playing indicator. Tapping an item loads it at zero, updates the shared session, and presents Now Playing when appropriate. Loading must finish its CarPlay selection callback on both success and failure.

**Reciters:** short list with localized names and the selected reciter indicated. A change during playback restarts the current surah; reflect the new name and loading state promptly. No confirmation dialog for this ordinary action. Keep the reciter choice accessible without phone interaction.

**Now Playing:** native `CPNowPlayingTemplate`, populated through shared Now Playing metadata and remote commands. Show surah title, reciter, duration when known, elapsed time, and playback state. Avoid artwork dependencies; a bundled neutral app image can be used after branding is chosen.

**Errors:** actionable short messages, such as “Unable to load this surah” with Retry. Keep the selected surah and reciter visible. Do not require phone unlocking to recover from an ordinary network error.

### List position requirement and fallback

On the phone, persist a stable visible surah ID, restore it on return, and use the current surah when there is no saved anchor. Do not save an unreliable pixel offset.

On CarPlay, preserve template instances where practical to avoid unnecessary list resets. The native template controls scrolling; exact offset access and programmatic positioning have not been verified. Prototype returning from Now Playing, switching tabs, reconnecting, and rebuilding for a language change. Check maximum item count in the SDK/runtime; do not silently truncate 114 surahs.

If public APIs cannot restore or target the row, record this limitation. Proposed fallback for owner review: retain Quran order and provide a clearly labeled Current Surah shortcut above the full list. Do not reorder the Quran list or introduce grouped navigation without discussing the resulting experience. The shortcut does not satisfy exact scroll restoration and must not be reported as if it does.

### iPhone

Surahs, Reciters, and Settings, with a compact player opening a full playback screen. Selecting surahs and reciters follows identical rules to CarPlay. The playback screen supports play/pause, next/previous, elapsed time, duration, and seek where supported by the media.

Settings: app language, automatic CarPlay resume policy, source/attribution information, and app information. No nonfunctional download controls in v1. Use Dynamic Type, VoiceOver labels, sufficient contrast, and accessible button targets. Validate Arabic layout and mixed Arabic/Latin text on both surfaces.

## 5. Playback rules and lifecycle

Use one playback coordinator for all entry points: phone controls, CarPlay actions, lock-screen controls, steering-wheel controls, and automatic continuation. Views must not create their own players or independent queues.

Suggested states: idle, loading, playing, paused, buffering, failed, completed. Store user intent separately from transport state (for example, a user pause during buffering must prevent a late retry from starting playback).

Each selection receives an operation/generation identifier. Discard stale network/player callbacks after a new surah or reciter is selected. Serialize state changes and update observable UI state on the main actor. Ensure an end-of-item event can advance the queue only once.

Save a versioned checkpoint periodically while playing (proposed five seconds), and on pause, seek completion, item change, interruption, and car disconnection. Do not rely on app termination callbacks. Restore metadata on launch without implicitly starting phone audio.

Resume only the exact recording collection that produced the saved timestamp. If that recording changes or disappears, retain context, explain the problem, and require explicit action; never apply a timestamp to a different reciter. Clamp a restored position to a valid duration after metadata loads. A completed session stays completed.

Prepare the next item ahead of natural completion where appropriate; transition exactly once and update Now Playing metadata. An unavailable next recording stops with Retry, rather than skipping over Quran content.

For streaming stalls, proposed retry delays are 1, 2, and 4 seconds, bounded by a 20-second recovery window. This is a policy to test, not a provider guarantee. Cancel retries on pause, disconnection, or new selection. Authentication/permission errors and missing files should become actionable failures rather than a retry storm. Network reachability is a hint, not proof that streaming works.

Use a playback audio session and background audio capability. Handle calls, Siri, navigation audio, route changes, and media-service resets using platform guidance. Resume after interruptions only when platform signals and prior user intent allow it. Never resume after the user explicitly paused during an interruption. Pause on loss of the car audio route, and do not automatically transfer playback to the phone speaker.

## 6. Automatic CarPlay resume: feasibility gate

The user explicitly wants playback to start automatically on connection. Apple advises user-initiated playback in general, with exceptions including resuming interrupted audio. A CarPlay connection, app scene connection, and audio route becoming available are different events; do not assume one always provides background execution for another.

Prototype with a real car and record: app already running, backgrounded, not running, manually force-quit, phone locked, wired/wireless where available, previously playing, previously paused, another audio app playing, and no saved session. Do not claim guaranteed launch or playback in unsupported lifecycle states.

Preferred policy proposal: resume an eligible prior session once when CarPlay and a suitable route are available and the preference is enabled; avoid duplicate starts and avoid overriding a deliberate pause in the current connection. Treat taking over another audio app and resuming a previously manually paused session as open policy decisions to resolve with the owner after the prototype. Automatic playback must never occur on ordinary phone app launch.

Exit evidence: supported cases, unsupported cases, relevant Apple guidance, tested device/OS/head unit, and a recommended shippable policy. If the requested behavior cannot be supported, present the exact limitation and fallback to the owner before changing the requirement.

## 7. Audio catalog and permission

Candidate provider: MP3Quran's documented v3 API. Its reciter endpoint includes language, reciter, riwayah, and surah filters. This is evidence of a useful discovery API, not proof of unrestricted audio redistribution or future offline-download rights. Do not build against a staging API merely because it appears in search results.

Before integrating production audio:

1. Verify the production API and terms, permitted direct streaming, required attribution, rate limits, and future download/caching rights. Record dated evidence and any required permission. Do not contact providers without user authorization.
2. Resolve each proposed reciter to a stable provider identity and a particular complete recording collection. Verify Arabic and English names manually, not with name-string matching alone.
3. Confirm 114 surahs, canonical numbering, HTTPS URLs, duration loading, seeking/range behavior, redirect behavior, and reliable playback of long surahs. Inspect metadata for inconsistent or missing files.
4. Use returned/documented media URLs and format rules; do not guess hostnames or rely on a reciter name in a URL.
5. Keep audio attribution and metadata provenance in the catalog. Respect original recordings; do not insert, remove, or duplicate basmala, narration, or other content.

Bundle canonical bilingual surah metadata from a verified, permitted source so browsing does not require live catalog access. Cache validated provider metadata with a version and last-known-good fallback. Do not cache entire audio files persistently under the guise of streaming until rights and downloads are designed.

If provider terms remain unclear, keep implementation moving with test-owned audio and a mock catalog; production distribution remains blocked on the source decision.

Reviewed 2026-11-07. The live v3 endpoint `https://mp3quran.net/api/v3/reciters` returned the four proposed reciters, each with one Hafs an Asim murattal moshaf whose `surah_list` is 1–114. Audio URLs are `{server}{surah as three digits}.mp3` using the `server` value from that response (HTTPS on `cdn.mp3quran.net`). Sample files for surahs 1, 2, 18, and 114 returned `audio/mpeg`. MP3Quran's English privacy page, copyrights section, says all rights are available to everyone and any visitor or developer may copy material or use any link on the site. The app streams those links and does not store the files. That sentence is not a separate written license for App Store redistribution or offline downloads; those stay out of scope until a clearer grant exists. Automated tests keep using the synthetic tones.

## 8. Proposed architecture and data

Use native Swift, SwiftUI for the phone, CarPlay framework for car scenes, AVFoundation for playback, and MediaPlayer for Now Playing and remote commands. Start with Apple frameworks, URLSession, and simple persistence; no third-party dependencies are currently needed.

Suggested boundaries:

- `Domain`: Surah, Reciter, RecordingCollection, RecordingID, PlaybackSession, settings, and playback commands.
- `Catalog`: provider adapter, bilingual static metadata, availability validation, cached catalog.
- `Playback`: one coordinator, AVPlayer/AVQueuePlayer adapter, audio-session handling, interruption/route handling, and remote-command bridge.
- `Persistence`: versioned session checkpoint and settings. Use atomic local writes for the session; UserDefaults is suitable for small preferences.
- `Phone`: SwiftUI views consuming coordinator state.
- `CarPlay`: scene delegate and template controllers translating the same commands and state.

Use IDs rather than localized names as keys. Recording identity includes provider, collection, and surah number. Session stores recording identity, elapsed seconds, completion status, and checkpoint date. Settings store preferred reciter/collection, language preference, and resume policy. List position is a separate UI preference, not playback progress.

Inject catalog, player abstraction, clock/retry scheduler, and persistence for deterministic behavior tests. Keep production composition in the app entry point. A CarPlay scene disconnect must not destroy the global session or lose progress.

Future downloads should slot behind an audio-source resolver choosing verified local media or a remote URL for the same RecordingID. Do not implement a download database, background transfers, or storage management in v1. Future Siri selection requires a separate feasibility and Arabic-name recognition investigation.

## 9. Privacy and release readiness

Proposed local-only preferences and history, with no app-owned accounts or analytics. Streaming still exposes requests to the audio provider; do not describe the app as having no network data exposure. Determine App Store privacy disclosures from actual code and provider behavior. Publish accurate attribution, privacy information, support contact, and review notes before release.

Request/check the CarPlay audio entitlement early. Developer membership alone does not establish entitlement approval. Validate the final signing profile on a physical device. Complete TestFlight and parked-car testing before public release. Do not publish, enroll in paid services, or submit review materials merely because this document describes them.

## 10. Sources and evidence limits

Reviewed November 6, 2026. Recheck SDK details during implementation. No CarPlay UI or audio behavior has been device-tested yet.

- [Apple CarPlay framework](https://developer.apple.com/documentation/carplay)
- [Apple CarPlay audio sample](https://developer.apple.com/documentation/carplay/integrating-carplay-with-your-music-app)
- [Apple CarPlay human interface guidance](https://developer.apple.com/design/human-interface-guidelines/carplay) — automatic playback guidance.
- [CPListTemplate](https://developer.apple.com/documentation/carplay/cplisttemplate) and [CPListItem](https://developer.apple.com/documentation/carplay/cplistitem) — native lists and playing indicators; exact scroll control remains unverified.
- [Audio route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes)
- [Audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)
- [MP3Quran API documentation](https://www.mp3quran.net/ug/api) — official v3 endpoint and filter documentation; permission review remains open.
