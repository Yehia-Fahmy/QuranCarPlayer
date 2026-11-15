# Offline audio downloads

QuranCarPlayer supports user-initiated, per-surah downloads on the iPhone. Open a surah in
Now Playing and choose **Download for Offline**. The control shows determinate progress when the
server provides a content length, supports cancellation and retry, and changes to
**Available Offline** when installation succeeds. Its menu removes that recording.

The Surahs screen has a Downloads toolbar button, and Settings has a **Manage Downloads** row. The
dedicated screen rebuilds its inventory from app-owned files, so saved items remain visible without
a network connection or a separate database. Files from a collection no longer present in the
current catalog remain removable and are labeled with their stored collection identity. Legacy
PR #2 paths are migrated to collision-free structured paths on launch. The screen shows:

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
- Network bytes stream to a temporary file. A non-empty completed file is moved through a
  same-directory staging path before it becomes visible to playback.
- Partial staging files are cleaned at launch. Downloads are excluded from device backups.
- Cancelling, a failed response, an empty response, or a write failure removes temporary data and
  leaves streaming available. Downloads are foreground operations and do not claim to continue
  after the app is suspended or terminated.
- If the player rejects a downloaded file, the app removes that file and immediately falls back to
  the catalog stream at the retained position instead of retrying broken local media.
- Removing a file affects future loads. An already-open player item may continue until it is
  replaced; subsequent playback streams if the local file is gone.

## Source permission caveat

The code enables local storage but does not establish legal permission to distribute that feature.
The provider review in `docs/DESIGN.md` found language permitting use of published links, but not a
separate, explicit offline-download or App Store redistribution license. Confirm the provider's
current terms or obtain permission before publicly shipping offline downloads.

## Verification

Core tests cover atomic persistent storage, rejection and cleanup of incomplete files, exact-recording
local resolution, streaming fallback, successful download state, failures, and rebuilding the
management inventory with exact per-item sizes. Run:

```sh
Scripts/test-core.sh
```

An iOS build and manual check should additionally verify progress, cancellation, relaunch persistence,
remove/remove-all, playback with networking disabled, Arabic layout, and behavior under low storage.
