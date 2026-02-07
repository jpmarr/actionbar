import Foundation

struct SettingsStorage {
    private enum Keys {
        static let pollInterval = "pollInterval"
        static let notificationsEnabled = "notificationsEnabled"
        static let notifyOnSuccess = "notifyOnSuccess"
        static let notifyOnFailure = "notifyOnFailure"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var pollInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: Keys.pollInterval)
            return value > 0 ? value : Configuration.defaultPollInterval
        }
        nonmutating set {
            defaults.set(newValue, forKey: Keys.pollInterval)
        }
    }

    var notificationsEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.notificationsEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.notificationsEnabled)
        }
        nonmutating set {
            defaults.set(newValue, forKey: Keys.notificationsEnabled)
        }
    }

    var notifyOnSuccess: Bool {
        get {
            if defaults.object(forKey: Keys.notifyOnSuccess) == nil { return false }
            return defaults.bool(forKey: Keys.notifyOnSuccess)
        }
        nonmutating set {
            defaults.set(newValue, forKey: Keys.notifyOnSuccess)
        }
    }

    var notifyOnFailure: Bool {
        get {
            if defaults.object(forKey: Keys.notifyOnFailure) == nil { return true }
            return defaults.bool(forKey: Keys.notifyOnFailure)
        }
        nonmutating set {
            defaults.set(newValue, forKey: Keys.notifyOnFailure)
        }
    }
}
