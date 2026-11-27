# Quran Foundation chapter recordings

Checked November 27, 2026. Quran.com lists Murattal editions for all nine reciters in Quran Carplayer. For each edition, its public chapter manifest returned one audio URL for every surah from 1 through 114. That covers 1,026 reciter–chapter combinations. The Foundation catalog identifies the reciter and style. The check did not establish the riwayah of each recording or whether it is the same performance as the MP3Quran edition. [Quran.com reciter directory](https://quran.com/en/reciters) · [App catalog](../../../Packages/QuranCarPlayerCore/Sources/QuranCarPlayerCore/Resources/mp3quran-catalog.json)

## Editions checked

All 1,026 URLs answered a request for bytes 0–511 with HTTP 206, an `audio/mpeg` content type and an ID3 or MPEG audio frame header. This verifies that the CDN served audio at every listed URL on the check date. Full-length playback and audio quality were outside the check.

| Reciter in Quran Carplayer | Foundation chapter-reciter ID and manifest | Numbered chapters |
| --- | --- | --- |
| Maher Al-Muaiqly | [159](https://api.quran.com/api/v4/chapter_recitations/159), labeled beta | 1–114 |
| Mishary Rashid Alafasy | [7](https://api.quran.com/api/v4/chapter_recitations/7) | 1–114 |
| Abdul Rahman Al-Sudais | [3](https://api.quran.com/api/v4/chapter_recitations/3) | 1–114 |
| Saud Al-Shuraim | [10](https://api.quran.com/api/v4/chapter_recitations/10) | 1–114 |
| Saad Al-Ghamdi | [13](https://api.quran.com/api/v4/chapter_recitations/13) | 1–114 |
| Mahmoud Khalil Al-Hussary | [6](https://api.quran.com/api/v4/chapter_recitations/6) | 1–114 |
| Mohammed Siddiq Al-Minshawi | [9](https://api.quran.com/api/v4/chapter_recitations/9) | 1–114 |
| Abdulbasit Abdulsamad | [2](https://api.quran.com/api/v4/chapter_recitations/2) | 1–114 |
| Yasser Al-Dosari | [174](https://api.quran.com/api/v4/chapter_recitations/174), labeled beta | 1–114 |

The IDs come from Quran.com's reciter directory. The public `resources/chapter_reciters` response omitted Maher and Saad and listed a different edition for Yasser. The individual manifests linked above include all three selected editions. For Sudais, the manifest also returned one unnumbered row with an empty audio URL, which was excluded. A production integration can identify chapter audio by chapter-reciter ID and chapter number. [Chapter-audio API reference](https://api-docs.quran.foundation/docs/content_apis_versioned/4.0.0/chapter-reciter-audio-files/)

## Offline use

Quran Foundation permits direct streaming and user-requested downloads to private app storage. A migration would need to credit the Foundation and reciters, prevent file export, and support deletion. For editions in Content Sync, the app must obtain and maintain the catalog through that service, synchronize at least every seven days when reachable, delete withdrawn recordings and replace a recording when its URL changes. Users may keep listening during longer periods offline. These conditions apply to Foundation-hosted audio. The current app uses MP3Quran. [Offline listening terms](https://api-docs.quran.foundation/docs/tutorials/faq/#can-my-app-let-users-download-recitations-for-offline-listening) · [Content Sync](https://api-docs.quran.foundation/docs/tutorials/content-sync/getting-started/)
