import Foundation
import Sparkle

@MainActor
@Observable
final class UpdaterModel: NSObject, SPUUpdaterDelegate {
    enum Status: Equatable {
        case unknown
        case upToDate
        case updateAvailable(version: String)
    }

    private(set) var status: Status = .unknown

    @ObservationIgnored
    private(set) lazy var controller: SPUStandardUpdaterController = .init(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    override init() {
        super.init()
        _ = controller
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    func installUpdate() {
        controller.checkForUpdates(nil)
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        Task { @MainActor in self.status = .updateAvailable(version: version) }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in self.status = .upToDate }
    }
}
