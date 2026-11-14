# QuranCarPlayer

A planned iPhone Quran audio player designed primarily for easy surah and reciter selection through Apple CarPlay. Initially for personal use, with a future free App Store release.

**Status (November 14, 2026): the phone app streams four Hafs recitations and has played them on the owner's iPhone.** Signing uses `yehia.fahmy@uwaterloo.ca` and bundle ID `com.yehiafahmy.QuranCarPlayerApp`. After that developer certificate was trusted, the app launched to the surah list with Maher Al-Muaiqly selected. Core playback logic is unit-tested on macOS. Automated tests still use labelled synthetic tones. Lock-screen controls, background audio, the CarPlay entitlement, and in-car resume stay open. Offline downloads are not included.

## Start here

1. Read [the product and technical design](docs/DESIGN.md).
2. Follow [environment setup](docs/ENVIRONMENT.md) — see "Owner actions required".
3. Use [build and test procedure](docs/BUILD_AND_TEST.md); `Scripts/test-core.sh` works with only the Command Line Tools.
4. Read [feasibility notes](docs/FEASIBILITY.md) on automatic CarPlay resume and list position.
5. Work through [implementation milestones and acceptance checks](docs/IMPLEMENTATION.md); the handoff record at the end lists the next concrete task.

## Layout

- `Packages/QuranCarPlayerCore` — platform-independent domain, catalog, playback coordinator, persistence, and AVFoundation/MediaPlayer adapters (SwiftPM, testable on macOS).
- `App/` — iOS app: SwiftUI phone UI, CarPlay scene and templates, composition root, localization, test audio.
- `AppTests/` — app-bundle smoke tests (run in Xcode).
- `UITests/` — phone playback UI tests (simulator). They launch with `-QCPUITestReset` so each test starts from default settings.
- `project.yml` → `QuranCarPlayer.xcodeproj` (XcodeGen; generated project is committed with a shared scheme).
- `Config/` — build settings; signing values are local and gitignored.
- `Scripts/` — core test runner, project generation, test-audio generation.

Confirmed user decisions are distinguished from proposed implementation defaults. Do not silently change confirmed behavior to accommodate a platform limitation: document the evidence and propose a concrete alternative.

The first implementation work should validate CarPlay automatic resume and list-position behavior, and establish an approved audio source. Downloads and Siri selection are later features. Favorites and recently played lists are not part of the design.

Planning date: November 6, 2026 (America/Toronto).
