import Foundation
import Carbon
import AppKit

@MainActor
final class GlobalHotkey {
    static let shared = GlobalHotkey()
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func register() {
        // ⌃⌘B → key code for B is 11; modifiers cmdKey + controlKey from <Carbon/HIToolbox/Events.h>
        let modifiers: UInt32 = UInt32(cmdKey | controlKey)
        let keyCode: UInt32 = 11

        let signature: OSType = {
            let chars = Array("BNTO".utf8)
            return UInt32(chars[0]) << 24 | UInt32(chars[1]) << 16 | UInt32(chars[2]) << 8 | UInt32(chars[3])
        }()
        let id = EventHotKeyID(signature: signature, id: 1)

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { _, _, _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .bentoTogglePanel, object: nil)
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, nil, &handler)
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }
}
