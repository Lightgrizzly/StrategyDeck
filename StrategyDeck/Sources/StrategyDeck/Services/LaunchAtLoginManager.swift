import Foundation
import ServiceManagement

/// Wraps SMAppService to enable/disable launch-at-login.
///
/// SMAppService was added in macOS 13 and replaced the older
/// SMLoginItemSetEnabled approach. It requires the binary to be inside a
/// properly-signed .app bundle with a registered helper. When running as
/// a plain `swift run` binary (not a bundled .app), the registration will
/// fail gracefully and `isEnabled` will report false.
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    @Published var lastError: String?

    private let service = SMAppService.mainApp

    init() {
        refresh()
    }

    var isAvailable: Bool {
        // Only available inside a properly-installed .app bundle.
        service.status != .notRegistered || Bundle.main.bundleURL.pathExtension == "app"
    }

    func refresh() {
        isEnabled = service.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            refresh()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }
}
