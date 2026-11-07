import SwiftUI
import QuranCarPlayerCore

@main
struct QuranCarPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            // Production composition lives in `AppEnvironment`; the phone and CarPlay scenes
            // both read from this single instance so there is exactly one playback session.
            RootView(coordinator: AppEnvironment.shared.coordinator)
        }
    }
}
