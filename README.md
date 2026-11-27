# Quran Carplayer

An iPhone Quran audio player with Apple CarPlay, nine reciters from Quran Foundation, and per-surah offline downloads that last seven days. Existing MP3Quran downloads continue to work on the same device.

The [release change record](docs/RELEASE_READINESS.md) tracks the offline playback, CarPlay and chapter artwork fixes, verification results, and decisions for App Store submission.

## Start here

1. Read [the product and technical design](docs/DESIGN.md).
2. Follow [environment setup](docs/ENVIRONMENT.md) — see "Owner actions required".
3. Use [build and test procedure](docs/BUILD_AND_TEST.md); `Scripts/test-core.sh` works with only the Command Line Tools.
4. Read [feasibility notes](docs/FEASIBILITY.md) on automatic CarPlay resume and list position.
5. Work through [implementation milestones and acceptance checks](docs/IMPLEMENTATION.md); the handoff record at the end lists the next concrete task.
6. See [offline download behavior and verification](docs/OFFLINE_DOWNLOADS.md).

## Layout

- `Packages/QuranCarPlayerCore` — platform-independent domain, catalog, playback coordinator, persistence, and AVFoundation/MediaPlayer adapters (SwiftPM, testable on macOS).
- `App/` — iOS app: SwiftUI phone UI, CarPlay scene and templates, composition root, localization, test audio.
- `AppTests/` — app-bundle smoke tests (run in Xcode).
- `UITests/` — phone playback UI tests (simulator). They launch with `-QCPUITestReset` so each test starts from default settings.
- `project.yml` → `QuranCarPlayer.xcodeproj` (XcodeGen; generated project is committed with a shared scheme).
- `Config/` — build settings; signing values are local and gitignored.
- `Scripts/` — core test runner, project generation, test-audio generation.

Confirmed user decisions are distinguished from proposed implementation defaults. Do not silently change confirmed behavior to accommodate a platform limitation: document the evidence and propose a concrete alternative.

Planning date: November 6, 2026 (America/Toronto).
