import Foundation
import Sparkle

@MainActor
final class UpdateController {
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func startAutomaticChecks() {
        updaterController.startUpdater()
    }

    func checkForUpdates(sender: Any?) {
        updaterController.checkForUpdates(sender)
    }
}
