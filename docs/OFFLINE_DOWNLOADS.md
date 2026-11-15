# Offline audio downloads

QuranCarPlayer supports user-initiated, per-surah downloads on the iPhone. Open a surah in
Now Playing and choose **Download for Offline**. The control shows determinate progress when the
server provides a content length, supports cancellation and retry, and changes to
**Available Offline** when installation succeeds. Its menu removes that recording. Settings shows
the stored file count and size and can remove all downloads.

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
local resolution, streaming fallback, successful download state, and failures. Run:

```sh
Scripts/test-core.sh
```

An iOS build and manual check should additionally verify progress, cancellation, relaunch persistence,
remove/remove-all, playback with networking disabled, Arabic layout, and behavior under low storage.
