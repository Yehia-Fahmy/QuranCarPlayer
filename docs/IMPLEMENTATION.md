# Implementation milestones and acceptance checks

Read DESIGN.md and ENVIRONMENT.md first. Work in small reviewable changes. Check off work only with evidence; these tasks are all pending. Keep confirmed product requirements separate from defaults and platform limitations. Update these documents as decisions are resolved.

## Milestone 0 — Toolchain and feasibility

- [ ] Establish the Xcode toolchain, app project, shared scheme, simulator, and device signing.
- [ ] Verify/request CarPlay audio entitlement through the owner's account.
- [ ] Build a small native CarPlay list and Now Playing prototype with test-owned audio.
- [ ] Test 114-item browsing, native playing indicators, returning to a list, tab switching, reconnecting, and list-position restoration using public APIs.
- [ ] Test automatic resume in all lifecycle cases listed in DESIGN.md. Resolve the manually-paused-session and other-audio-app policies with the owner using findings.
- [ ] Verify production audio provider permissions, attribution, and the four candidate recording collections. Document evidence and any unavailable reciter.

Deliverable: reproducible prototype and a dated feasibility note with device/SDK details, actual results, limitations, and owner decisions. Do not wait for entitlement or source approval to implement independent domain logic and phone functionality with fixtures.

## Milestone 1 — Catalog and playback foundation

- [ ] Define stable surah, reciter, collection, recording, and session IDs.
- [ ] Add verified bilingual surah metadata; validate exactly 114 unique sequential IDs.
- [ ] Implement provider adapter and last-known-good catalog cache with fixture tests.
- [ ] Build shared playback coordinator, intent-aware state transitions, retry cancellation, and stale-operation rejection.
- [ ] Implement continuous ordered playback, next/previous boundaries, reciter changes, checkpoint restore, and completed-session handling.
- [ ] Add audio-session handling, background playback, Now Playing metadata, and remote commands.

Exit: playback works on the phone while locked, state survives a relaunch, controls act on one shared session, and policy tests pass without network access.

## Milestone 2 — Phone interface

- [ ] Surah list, saved visible anchor/current-surah positioning, reciter selection, player, and settings.
- [ ] System/English/Arabic localization and right-to-left layout.
- [ ] Loading, buffering, retry, first-use, and completed-session states.
- [ ] Dynamic Type and VoiceOver checks on key controls and bilingual names.

Exit: a new user can select a surah, change reciter, pause, resume, seek, and change language; no account is required.

## Milestone 3 — CarPlay interface

- [ ] Native Listen / Surahs / Reciters templates and native Now Playing.
- [ ] Shared state synchronization across phone, car, and remote controls.
- [ ] Implement proven list-position behavior; obtain owner agreement for any fallback.
- [ ] Implement validated automatic resume policy and car-disconnection pause.
- [ ] Handle scene reconnects, selection callbacks, loading cancellation, language rebuilds, and errors without losing playback position.

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
