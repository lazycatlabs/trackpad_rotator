import Foundation
import Observation

/// User-editable settings; every change is saved and handed to the engine.
@MainActor @Observable
final class SettingsViewModel {
    var config: EngineConfig {
        didSet {
            guard config != oldValue else { return }
            repository.save(config)
        }
    }

    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            repository.setLaunchAtLogin(launchAtLogin)
        }
    }

    @ObservationIgnored private let repository: SettingsRepository

    init(repository: SettingsRepository = .shared) {
        self.repository = repository
        config = repository.load()
        repository.applyLaunchAtLoginDefault()
        launchAtLogin = repository.launchAtLogin
    }

    func resetAxes() {
        config.transform = AxisTransform(rotation: config.transform.rotation)
    }
}
