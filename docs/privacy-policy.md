# Privacy Policy — Quran Carplayer

**Effective date:** 16 November 2026  
**Last updated:** 27 November 2026\
**Developer:** Yehia Fahmy  
**Contact:** [yehia.fahmy@uwaterloo.ca](mailto:yehia.fahmy@uwaterloo.ca)

> **Hosting note (not for published page):** Publish this document at a stable HTTPS URL (for example under your site or GitHub Pages). Enter that URL as the Privacy Policy URL in App Store Connect and link it from in-app Settings when available.

This Privacy Policy describes how **Quran Carplayer** (“the App”) handles information. It applies to the iPhone and Apple CarPlay experience of the App.

## Summary

- The App does **not** require an account and does **not** ask you to provide your name, email, or phone number to use it.
- Preferences, listening progress, and optional offline audio files are stored **on your device**.
- When you stream or download recitations, the App contacts the audio provider over HTTPS. Build 7 uses **MP3Quran**. Build 6 uses Quran Foundation.
- The App does **not** include advertising, analytics, crash-reporting, or tracking SDKs, and does **not** use App Tracking Transparency / advertising identifiers for tracking.
- We do **not** sell your personal information.

## Who we are

Quran Carplayer is developed by Yehia Fahmy. For privacy questions, email [yehia.fahmy@uwaterloo.ca](mailto:yehia.fahmy@uwaterloo.ca).

## Information stored on your device

The App stores the following locally on your iPhone (and related Apple system surfaces such as Now Playing), not on developer-operated servers:

### Preferences

Small settings such as preferred reciter, language preference (system / English / Arabic), CarPlay automatic-resume preference, and a surah-list anchor. These are stored using Apple’s `UserDefaults` on the device.

### Listening session (“Continue Listening”)

A local session checkpoint (for example, which recording you were listening to, elapsed time, completion status, and when it was saved) is written as a file in the App’s Application Support directory so you can continue where you left off.

### Optional offline downloads

If you choose to download a surah for offline listening, the audio file is saved in the App’s Application Support storage on your device. Downloads are user-initiated. Downloaded files are marked so they are **not** included in iCloud backup. You can remove individual downloads or all downloads from the App’s Downloads screen.

### System UI metadata

While audio is playing, the App may provide Now Playing metadata (such as title, reciter, and artwork) to Apple system frameworks so lock screen, Control Center, and CarPlay Now Playing can display what is playing. That presentation is handled by the operating system.

We do **not** operate an account system, cloud sync service, or developer backend that receives these local preferences, session files, or offline downloads.

## Network activity

### Audio streaming and downloads

Reciter catalog metadata used by the App is bundled with the App. Audio itself is fetched over HTTPS from MP3Quran (`cdn.mp3quran.net`) in build 7 or from Quran Foundation’s audio host (`download.quranicaudio.com`) in build 6 when you:

- stream a recitation, or
- download a recitation for offline use.

Those requests necessarily include ordinary technical request data that any HTTPS client sends (for example, IP address, user-agent style network metadata, and the URL of the requested audio file) so the CDN can deliver the file. The App does not add an analytics identity, advertising ID, or account credential to those requests.

MP3Quran’s [privacy policy](https://www.mp3quran.net/privacy-en.html) describes website logs that include the visitor’s IP address, visit time, country and referring page. It does not specify how long the audio host keeps requests or whether it stores the chapter URL with the listener’s IP address. For build 6, Quran Foundation describes website logs in its [privacy policy](https://quran.com/privacy). A recording choice may reveal religious interests. The app does not create a religious profile or use listening activity for advertising, profiling, or AI training. Playing a saved chapter reads the audio from your device.

### Minshawi’s portrait

When the app needs this portrait, it checks the App Store storefront through StoreKit. In the Canadian and U.S. storefronts it can fetch one historical JPEG from Wikimedia Commons over HTTPS and cache it privately on your iPhone for offline display. Wikimedia logs image requests, including the IP address and image URL, and can derive an approximate location from the IP address. Its traffic logs are generally purged after 90 days. See [Wikimedia’s request-log documentation](https://wikitech.wikimedia.org/wiki/Data_Platform/Data_Lake/Traffic/Webrequest). The request contains no chapter number, listening position or account identifier. Where the image is unavailable, the app draws geometric artwork locally. See the [Wikimedia privacy policy](https://foundation.wikimedia.org/wiki/Policy:Privacy_policy).

### Links you open

If you tap attribution or license links in Settings (for example Wikimedia Commons or license pages), those open in your browser or system link handler. Activity on those websites is subject to the websites’ own privacy practices.

### What we do not do on the network

The App does not send preferences, session checkpoints, download inventories, or analytics events to servers operated by the developer. There is no developer-operated analytics, advertising, or crash-reporting endpoint in the App.

## Tracking

The App does **not** track you across other companies’ apps and websites for advertising. It does not use the App Tracking Transparency advertising identifier for tracking, and it does not include advertising or data-broker SDKs.

## How we use information

On-device information is used only to operate App features you request:

- remember preferences and language,
- resume listening,
- play and manage offline downloads,
- show Now Playing information,
- contact the audio CDN when you stream or download.

## Sharing and sale of data

- We do **not** sell personal information.
- We do **not** share on-device preferences, session files, or downloads with advertisers.
- The app requests audio from the provider for the recording you choose.
- We may disclose information if required by law, or to protect rights, safety, and integrity, to the limited extent such information is available to us (for most users, that is limited to support email correspondence if you contact us).

## Data retention and deletion

- **Preferences and session checkpoint:** remain on your device until you change them, clear App data by deleting the App, or otherwise remove the App’s data through iOS Settings.
- **Offline downloads:** MP3Quran downloads stay on your device until you remove the recording or delete the app. Recordings saved from Quran Foundation in build 6 expire seven days after their original download. The app removes expired files when it can run. Use **Settings → Manage Downloads** in the App to remove one recording or all downloads.
- **Support email:** if you email us, we keep the correspondence as needed to respond and then according to ordinary mailbox retention.

Deleting the App removes the App’s local container on that device (including preferences, session checkpoint, and downloads stored there).

## Children

The App is a Quran audio player and does not target children with advertising or profiling. We do not knowingly collect personal information from children through a developer backend. If you believe a child has sent personal information to [yehia.fahmy@uwaterloo.ca](mailto:yehia.fahmy@uwaterloo.ca), contact us and we will delete that correspondence.

## International users

The App is distributed through the Apple App Store. Audio may be delivered from CDN infrastructure operated by the audio provider. Your iPhone stores listening progress and preferences. If you enable device backups, Apple can include this data in a backup and restore it to a device. You can manage iCloud Backup in iPhone Settings. Downloaded audio is excluded from backup.

## Changes to this policy

We may update this Privacy Policy when the App’s behavior or legal requirements change. The “Last updated” date at the top will change when we do. Continued use of the App after an update means you acknowledge the revised policy. Material changes will be reflected in the hosted policy URL used for the App Store listing.

## Contact

To ask about privacy or request a copy, correction or deletion of support correspondence, contact the developer at the email below. You can manage local listening data on your iPhone.

**Email:** [yehia.fahmy@uwaterloo.ca](mailto:yehia.fahmy@uwaterloo.ca)\
**Developer:** Yehia Fahmy  
**App:** Quran Carplayer

© 2026 Yehia Fahmy
