import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Hold to talk, release to transcribe. Default: Option+Space.
    static let pushToTalk = Self("pushToTalk", default: .init(.space, modifiers: [.option]))
}

final class HotkeyManager {
    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .pushToTalk, action: onKeyDown)
        KeyboardShortcuts.onKeyUp(for: .pushToTalk, action: onKeyUp)
    }
}
