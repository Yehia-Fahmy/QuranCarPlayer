# Support — Quran CarPlayer

**App:** Quran CarPlayer  
**Developer:** Yehia Fahmy  
**Support email:** [support@yehiafahmy.com](mailto:support@yehiafahmy.com)

> **Hosting note (not for published page):** Publish this document at a stable HTTPS Support URL for App Store Connect. Prefer a short public URL that opens cleanly on iPhone Safari.

Thank you for using Quran CarPlayer — a free Quran audio player for iPhone with Apple CarPlay support. This page covers how to get help, common questions, and what the App does and does not include.

## Contact

Email **[support@yehiafahmy.com](mailto:support@yehiafahmy.com)** with:

- your iPhone model and iOS version,
- whether the issue is on **iPhone**, **CarPlay**, or both,
- what you expected vs what happened,
- the reciter and surah (if playback-related).

We aim to reply as soon as practical. There is no in-app chat or account login.

## What the app does

- Stream complete **Hafs Murattal** Quran recitations from MP3Quran over HTTPS.
- Optionally **download** surahs you choose for offline listening.
- Continue listening from a local on-device checkpoint.
- Use the App on iPhone and with **Apple CarPlay®** (Audio).
- Switch UI language between system default, English, and Arabic.

## What the app does not include (v1)

- Accounts, cloud sync, or social features
- Ads, in-app purchases, or subscriptions
- Analytics or advertising tracking SDKs
- Microphone, location, contacts, photos, or camera access

## Getting started

1. Open **Quran CarPlayer** on iPhone.
2. Choose a **reciter**, then a **surah**, and press play.
3. For CarPlay: connect your iPhone to a CarPlay-capable vehicle (or use Apple’s CarPlay Simulator / Device Hub tools during development). Launch Quran CarPlayer from the CarPlay home screen.
4. Optional: download surahs from the phone UI for offline use (Downloads management is in Settings).

## FAQ

### Why does the app need a network connection?

Streaming fetches audio from the MP3Quran CDN. Offline playback works only for surahs you have already downloaded. The reciter list itself is bundled in the App, but audio files are not all preloaded.

### How do offline downloads work?

Open a surah in the iPhone player and choose **Download for Offline**. In **Settings → Manage Downloads**, you can cancel transfers, retry failures, or remove saved recordings. Downloads are stored only on your device and are excluded from iCloud backup. In Airplane Mode, previously downloaded surahs can play locally; undownloaded surahs need network streaming.

### Does the app collect my personal data?

Your iPhone stores preferences, listening progress and downloads. Apple can back up preferences and progress when device backups are enabled. Downloaded audio is excluded from backup. The developer does not run accounts or analytics backends. Streaming and download requests go to the audio CDN so the files can be delivered. See the [Privacy Policy](https://yehia-fahmy.github.io/QuranCarPlayer/privacy/).

### Can I delete local data?

- Remove offline audio in **Downloads**.
- Change or reset preferences in **Settings**.
- Delete the App from your iPhone to remove the App’s local data container on that device.

### CarPlay: playback won’t start or resumes unexpectedly

- Confirm CarPlay Audio entitlement builds are installed (development vs distribution profiles differ).
- If another audio app is already playing, Quran CarPlayer is designed **not** to steal audio when reconnecting.
- After you deliberately pause, the App is configured **not** to auto-resume merely because CarPlay reconnects.
- Try play again from the CarPlay Listen / Surahs / Reciters templates, or start playback on iPhone first.

### CarPlay: I can’t find my place in the surah list

Exact scroll restoration is limited by CarPlay list APIs. Use the labeled **Current Surah** shortcut / selection when available, or open the current surah from Listen / Now Playing.

### Audio stops, stalls, or fails to load

- Check network connectivity for streaming.
- Retry from the failure alert when shown.
- Confirm the surah is downloaded if you expect offline playback.
- Force-quit and reopen the App, then try again.
- Email support with reciter, surah number, and whether you were streaming or offline.

### Languages

The App supports English and Arabic strings. Choose **System**, **English**, or **Arabic** in Settings. Some reciter names and attributions may still appear in a mixed form depending on source metadata.

### Attribution and audio source

Audio is streamed/downloaded from **MP3Quran** (mp3quran.net). Reciter portrait artwork (where shown) includes source and license links in Settings. The Quran text itself is not sold by this App; this product is an audio player.

### Pricing

Quran CarPlayer is **free**. There are no subscriptions or in-app purchases in v1.

### Privacy Policy

Read the full policy: [Privacy Policy](https://yehia-fahmy.github.io/QuranCarPlayer/privacy/).

## Safety while driving

Use CarPlay controls that minimize distraction. Interact with complex settings on iPhone when it is safe and legal to do so. Follow local laws about device use while driving.

## App Store & feedback

If you contacted support about a bug, including your App version (Settings → About) helps. Feature requests are welcome at the same email; v1 scope stays focused on reliable listening, offline downloads, and CarPlay.

© 2026 Yehia Fahmy  
Apple CarPlay is a trademark of Apple Inc. Quran CarPlayer is not affiliated with or endorsed by Apple.
