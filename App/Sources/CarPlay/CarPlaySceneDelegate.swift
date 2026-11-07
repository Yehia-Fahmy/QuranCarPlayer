import UIKit
import CarPlay
import QuranCarPlayerCore

/// CarPlay scene delegate. Referenced from Info.plist (UISceneDelegateClassName).
///
/// The scene owns only templates. Playback state lives in `AppEnvironment.shared`, so a
/// scene disconnect never destroys the session or loses progress.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var templateController: CarPlayTemplateController?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        let environment = AppEnvironment.shared
        let controller = CarPlayTemplateController(interfaceController: interfaceController,
                                                   coordinator: environment.coordinator)
        templateController = controller
        controller.start()
        // Automatic resume policy is evaluated by the coordinator (at most once per connection).
        let decision = environment.coordinator.carPlayDidConnect()
        CarPlayDiagnostics.log("scene connected; auto-resume decision: \(decision)")
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        templateController?.stop()
        templateController = nil
        AppEnvironment.shared.coordinator.carPlayDidDisconnect()
        CarPlayDiagnostics.log("scene disconnected; playback paused and checkpointed")
    }
}

/// Lightweight logging for prototype evidence gathering (visible in Console.app).
enum CarPlayDiagnostics {
    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[CarPlay] \(message())")
        #endif
    }
}
