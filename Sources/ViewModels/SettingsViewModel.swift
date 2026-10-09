import Foundation

/// User-editable settings; every change is saved and handed to the engine.
final class SettingsViewModel: ObservableObject {
    @Published var config: EngineConfig {
        didSet {
            guard config != oldValue else { return }
            repository.save(config)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            repository.setLaunchAtLogin(launchAtLogin)
        }
    }

    private let repository: SettingsRepository

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
