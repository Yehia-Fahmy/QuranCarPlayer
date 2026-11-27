# Offline audio downloads

QuranCarPlayer supports user-initiated, per-surah downloads on the iPhone. Open a surah in
Now Playing and choose **Download for 7 Days**. The control shows determinate progress when the
server provides a content length, supports cancellation and retry, and changes to
**Available Offline** when installation succeeds. Its menu removes that recording.

The Surahs screen has a Downloads toolbar button, and Settings has a **Manage Downloads** row. The
dedicated screen rebuilds its inventory from app-owned files, so saved items remain visible without
a network connection or a separate database. Files from a collection no longer present in the
current catalog remain removable and are labeled with their stored collection identity. On launch,
the store consolidates the original colon-delimited directories and both older JSON key orders.
It renames saved `.audio` files to `.mp3` so Apple's player can recognize the recordings.
The screen shows:

- active transfers and failures with localized progress or error state;
- the surah and reciter for every item;
- per-recording size, total file count, and total storage;
- cancel, retry, and per-item remove actions when appropriate;
- confirmed **Clear All**, an empty state, and cleanup failure feedback.

The screen follows the app's English/Arabic setting, including right-to-left layout, Dynamic Type,
and explicit accessibility labels for progress, size, and management controls.

## Playback and storage behavior

- Playback resolves the exact `RecordingID` (provider, collection, and surah) to a verified local
  file first. If no valid file exists, it uses the catalog URL unchanged, preserving streaming.
- Completed files live under Application Support in an app-owned `Audio Downloads` directory.
  Provider identifiers are encoded before being used as path components.
- Two recordings can download at once. Further selections wait in a cancellable queue.
- Downloads require a full HTTP 200 response. The client checks declared and received sizes
  against a 256 MiB limit, checks the declared length when available, and decodes an audio
  sample before installing the file. Bytes stream to a temporary MP3 in the app's transfer
  folder. The verified transfer is moved into place using same-directory staging.
- Partial staging files are cleaned at launch. Downloads are excluded from device backups.
- Cancelling, a failed response, an empty response, or a write failure removes temporary data and
  leaves streaming available. Downloads are foreground operations and do not claim to continue
  after the app is suspended or terminated.
- If the player rejects a downloaded file, the app removes that file and immediately falls back to
  the catalog stream at the retained position instead of retrying broken local media.
- Removing a file affects future loads. An already-open player item may continue until it is
  replaced; subsequent playback streams if the local file is gone.

## Providers and retention

Build 6 streams and downloads new chapter recordings directly from Quran Foundation. Each download is initiated on the device, stays in the app’s private storage, and is eligible for playback for seven days. The app removes expired files when it can run. Listeners may download the chapter again. This device-only integration uses the Foundation’s direct-audio allowance. [Foundation terms, section 3.1](https://api-docs.quran.foundation/legal/developer-terms/#31-acceptable-use)

Recordings saved in build 5 or earlier retain their MP3Quran collection identity and remain available offline until removed. Fresh network playback uses the Foundation edition. The reciter and surah may be the same across providers even when the performances and timings differ. [Foundation catalog verification](app-store-connect/rights-evidence/quran-foundation-catalog.md)

## Verification

Core tests cover atomic persistent storage, rejection and cleanup of incomplete files, exact-recording
local resolution, streaming fallback, successful download state, failures, and rebuilding the
management inventory with exact per-item sizes. Run:

```sh
Scripts/test-core.sh
```

An iOS build and manual check should additionally verify progress, cancellation, relaunch persistence,
remove/remove-all, playback with networking disabled, Arabic layout, and behavior under low storage.
