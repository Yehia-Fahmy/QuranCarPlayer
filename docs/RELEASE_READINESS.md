# iPhone and CarPlay release record

November 27, 2026 · implementation verification on version 1.0.0, build 3 · based on upstream `b91fe59`

## Changes and verification

| Area | Change | Evidence |
| --- | --- | --- |
| Offline playback | Stable storage keys, migration of both JSON key orders and earlier colon-delimited paths, and promotion of old `.audio` files to playable `.mp3` files. Transfers validate the response, size and audio decoding before installation. | A live download of Maher's Al-Fatihah saved 330,623 bytes. The saved recording decoded and resolved on all 1,000 lookups after reopening the store. The simulator's real AVPlayer advanced using a saved synthetic MP3 with an unavailable fallback. [Download behavior](OFFLINE_DOWNLOADS.md) |
| CarPlay navigation | The complete chapter list remains flat where it fits. Smaller displays offer chapter ranges with paging and keep the current-chapter shortcut when space permits. Reciter pages adapt to the vehicle's limits. | Tests traversed chapters 1–114 at ten capacities, with and without a current chapter, including single-row and single-section layouts. [Navigation tests](../AppTests/CarPlayChapterBrowserTests.swift) |
| Playback and audio focus | Route loss and disconnect cancel pending interruption resume. Media-service resets wait for Play. Two seconds of playback progress reset the retry budget. Pause, failure and completion release audio focus. Now Playing republishes on relevant changes. | Regression coverage includes both event orders, repeated ready/failure cycles at one position, reconnect and explicit resume after reset. [Playback tests](../Packages/QuranCarPlayerCore/Tests/QuranCarPlayerCoreTests/PlaybackCoordinatorTests.swift) |
| Chapter artwork | The renderer centers the visible digits, widens three-digit badges, and aligns the Arabic title, transliteration and reciter credit to one edge for each interface language. | Inspected before and after renders for all nine reciters, including one-, two- and three-digit chapters, portraits and the geometric fallback. A pixel-level test checks horizontal and vertical centering. [Now Playing sheet](artwork/now-playing.jpg) · [CarPlay list sheet](artwork/carplay-list.jpg) · [Portrait credits and licenses](ARTWORK_ATTRIBUTION.md) |
| Signing and privacy | Release requires the CarPlay Audio entitlement and targets iPhone at the app target. Privacy and support copy now explain backup eligibility for preferences and listening progress. The branch includes the corrected GitHub Pages URLs. | The archive's signature verified, `com.apple.developer.carplay-audio` was true, and `UIDeviceFamily` was `[1]`. The corrected hosted copy takes effect when this branch is merged and Pages publishes it. |

### Test runs

Build 4, with the public display name and portrait credit updates, passed all 70 core tests and all 20 iPhone 17 simulator tests with zero skips, failures or runtime warnings in the simulator result.

- **Core:** 70 tests in 11 suites passed twice in separate processes with `Scripts/test-core.sh`.
- **iPhone 17 simulator, iOS 27.2:** all 20 app-bundle and UI tests passed with no runtime warnings.
- **Release archive:** Xcode 27.2 produced and verified a development-signed device archive. Local App Store export reported that no matching iOS App Store provisioning profile was installed. The local signing keychain contained no valid Apple Distribution identity.
- **Chapter index:** compared all 114 chapter numbers, Arabic names and transliterations against the Quran.com index. Numbering matched throughout. Arabic spelling differed on chapters 14, 34, 76, 78, 82 and 84. Transliteration differed on 20, 21, 42, 58 and 61. These are spelling or transliteration variants. The bundled labels were retained. [Reference index](https://api.quran.com/api/v4/chapters?language=en)

## Decisions and acceptance before submission

- **Distribution signing.** Use the owner's distribution-signing setup for `com.yehiafahmy.QuranCarPlayerApp`, with CarPlay Audio enabled in the App Store profile. Verify the exported build and provision a TestFlight release candidate.
- **Public contact.** The owner designated the monitored Waterloo mailbox on the support and privacy pages. Verify the published pages following the merge.
- **Name and storefront.** Build 4 uses **Tilawah Miles**. Select **United States only** for launch. The selected territory matches the documented U.S. basis for the Minshawi portrait. Apple's public U.S. software search returned no matches for the name on November 27. Final name availability and storefront selection are confirmed by saving the App Store Connect record.
- **Media rights and privacy answers.** The [rights record](app-store-connect/rights-evidence/mp3quran-2026-11-27.md) distinguishes the provider's public copying permission, alternative sources, and the remaining CDN retention question. Complete the App Privacy answers once retention and use are established.
- **In-car acceptance.** Use the release candidate in a parked vehicle with the phone locked. Check actual display cropping and contrast, chapter 114 on a restricted list, steering-wheel controls, background playback, and a saved chapter in airplane mode. During a call, disconnect the car, end the call, and confirm silence on the phone. Reconnect with another audio source playing.
- **App Store Connect.** Verify the processed build, screenshots, listing copy, age rating, content-rights and privacy declarations, pricing, storefronts and review contact. Include the CarPlay walkthrough and provider evidence in Review Notes. The live account record and an actual head unit were outside this verification.
