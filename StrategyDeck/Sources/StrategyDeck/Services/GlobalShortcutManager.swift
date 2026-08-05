import Carbon
import AppKit

/// Registers a global hot key (Cmd+Shift+Space) using Carbon's
/// RegisterEventHotKey API.
///
/// WHY CARBON (not NSEvent.addGlobalMonitor):
///   NSEvent global monitors are passive — they cannot consume or intercept the
///   key. They also require Accessibility permission for some key combinations.
///   Carbon RegisterEventHotKey is a system-level registration that works
///   without any special permission, intercepts the key before the front-most
///   app sees it, and is the standard approach for system-wide hot keys on macOS
///   (used by Spotlight, Alfred, Raycast, etc.).
///
/// The callback must be a C function pointer (non-capturing closure in Swift),
/// so we use a module-level static reference to reach the live instance.
final class GlobalShortcutManager {
    var onActivate: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    // C callback can't capture instance; static var bridges to the live instance.
    private static weak var instance: GlobalShortcutManager?

    init() {
        GlobalShortcutManager.instance = self
        register()
    }

    deinit {
        unregister()
    }

    // MARK: - Private

    private func register() {
        let hotKeyID = EventHotKeyID(signature: 0x53_44_5F_31, id: 1) // 'SD_1'

        // kVK_Space = 49, cmdKey | shiftKey
        let err = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard err == noErr else {
            print("[GlobalShortcut] RegisterEventHotKey failed: \(err)")
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Non-capturing C-compatible callback — accesses only the static var.
        let callback: EventHandlerUPP = { _, _, _ -> OSStatus in
            Task { @MainActor in
                GlobalShortcutManager.instance?.onActivate?()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }

    private func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }
}
