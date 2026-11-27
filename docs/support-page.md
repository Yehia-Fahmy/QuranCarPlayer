# Support — Quran Carplayer

**App:** Quran Carplayer\
**Developer:** Yehia Fahmy  
**Support email:** [yehia.fahmy@uwaterloo.ca](mailto:yehia.fahmy@uwaterloo.ca)

> **Hosting note (not for published page):** Publish this document at a stable HTTPS Support URL for App Store Connect. Prefer a short public URL that opens cleanly on iPhone Safari.

Thank you for using Quran Carplayer — a free Quran audio player for iPhone with Apple CarPlay support. This page covers how to get help, common questions, and what the App does and does not include.

## Contact

Email **[yehia.fahmy@uwaterloo.ca](mailto:yehia.fahmy@uwaterloo.ca)** with:

- your iPhone model and iOS version,
- whether the issue is on **iPhone**, **CarPlay**, or both,
- what you expected vs what happened,
- the reciter and surah (if playback-related).

We aim to reply as soon as practical. There is no in-app chat or account login.

## What the app does

- Stream Murattal Quran recitations from nine reciters via Quran Foundation over HTTPS.
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

1. Open **Quran Carplayer** on iPhone.
2. Choose a **reciter**, then a **surah**, and press play.
3. For CarPlay: connect your iPhone to a CarPlay-capable vehicle (or use Apple’s CarPlay Simulator / Device Hub tools during development). Launch Quran Carplayer from the CarPlay home screen.
4. Optional: download surahs from the phone UI for offline use (Downloads management is in Settings).

## FAQ

### Why does the app need a network connection?

Streaming fetches audio directly from Quran Foundation’s audio CDN. Offline playback works only for surahs you have already downloaded. The reciter list itself is bundled in the App, but audio files are not all preloaded.

### How do offline downloads work?

Open a surah in the iPhone player and choose **Download for 7 Days**. In **Settings → Manage Downloads**, you can cancel transfers, retry failures, or remove saved recordings. A new Quran Foundation download lasts seven days. After it expires, download it again while online. Audio saved from MP3Quran before the update remains available offline until you remove it. All downloads stay on your device and are excluded from iCloud backup. In Airplane Mode, previously downloaded surahs can play locally; undownloaded surahs need network streaming.

### Does the app collect my personal data?

Your iPhone stores preferences, listening progress and downloads. Apple can back up preferences and progress when device backups are enabled. Downloaded audio is excluded from backup. The developer does not run accounts or analytics backends. Streaming and download requests go to the audio CDN so the files can be delivered. See the [Privacy Policy](https://yehia-fahmy.github.io/QuranCarPlayer/privacy/).

### Can I delete local data?

- Remove offline audio in **Downloads**.
- Change or reset preferences in **Settings**.
- Delete the App from your iPhone to remove the App’s local data container on that device.

### CarPlay: playback won’t start or resumes unexpectedly

- Confirm CarPlay Audio entitlement builds are installed (development vs distribution profiles differ).
- If another audio app is already playing, Quran Carplayer is designed **not** to steal audio when reconnecting.
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

New recordings are performed by the reciter named in the player and supplied by [Quran Foundation](https://quran.foundation/). Settings lists the reciters and the photo credits and licenses. Eight portraits come with the app. In the Canadian and U.S. App Store storefronts, Minshawi’s 1954 portrait can be loaded from Wikimedia Commons. Geometric artwork appears before it loads or when it is unavailable.

### Terms of use

Quran Carplayer is offered under [Apple’s Standard Licensed Application End User License Agreement](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/). Quran Foundation provides the recordings for listening within the app. Downloads are private device copies. The [Foundation’s developer terms](https://api-docs.quran.foundation/legal/developer-terms/) describe the permission for in-app playback and the seven-day storage limit used by this version. For questions about these terms, contact the developer at the support address above.

### Pricing

Quran Carplayer is **free**. There are no subscriptions or in-app purchases in v1.

### Privacy Policy

Read the full policy: [Privacy Policy](https://yehia-fahmy.github.io/QuranCarPlayer/privacy/).

## Safety while driving

Use CarPlay controls that minimize distraction. Interact with complex settings on iPhone when it is safe and legal to do so. Follow local laws about device use while driving.

## App Store & feedback

If you contacted support about a bug, including your App version (Settings → About) helps. Feature requests are welcome at the same email; v1 scope stays focused on reliable listening, offline downloads, and CarPlay.

© 2026 Yehia Fahmy  
Apple CarPlay is a trademark of Apple Inc. Quran Carplayer is not affiliated with or endorsed by Apple.
