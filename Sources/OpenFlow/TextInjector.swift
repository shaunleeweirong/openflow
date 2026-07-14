import AppKit

/// Inserts text into the frontmost app's focused field.
///
/// Primary path: pasteboard + synthesized Cmd+V — fast, length-independent,
/// works in native, browser, and Electron apps. Clipboard is snapshotted and
/// restored only if we still own the pasteboard (guards against races).
/// Fallback path: chunked CGEvent Unicode typing for paste-blocked fields.
/// Both require the Accessibility permission to post events.
final class TextInjector {
    enum Mode: String {
        case paste
        case type
    }

    func inject(_ text: String, mode: Mode, restoreClipboard: Bool) {
        guard !text.isEmpty else { return }
        switch mode {
        case .paste: injectViaPaste(text, restore: restoreClipboard)
        case .type: injectViaTyping(text)
        }
    }

    // MARK: - Paste path

    private func injectViaPaste(_ text: String, restore: Bool) {
        let pasteboard = NSPasteboard.general
        let snapshot = restore ? snapshotPasteboard(pasteboard) : []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ourChangeCount = pasteboard.changeCount

        // Let the pasteboard write settle before the paste keystroke.
        usleep(60_000)
        postCmdV()

        if restore, !snapshot.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                // Only restore if nothing else has claimed the pasteboard since us.
                guard pasteboard.changeCount == ourChangeCount else { return }
                self?.restorePasteboard(snapshot, to: pasteboard)
            }
        }
    }

    private func postCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // kVK_ANSI_V
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else { return }
        // Force flags to exactly Cmd so a still-held push-to-talk modifier
        // (e.g. Option) doesn't turn this into Cmd+Opt+V.
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: - Type-out fallback

    private func injectViaTyping(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let utf16 = Array(text.utf16)
        // CGEvent unicode strings max out around 20 UTF-16 units per event.
        let chunkSize = 18
        var index = 0
        while index < utf16.count {
            let chunk = Array(utf16[index..<min(index + chunkSize, utf16.count)])
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                keyDown.flags = []
                keyDown.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                keyUp.flags = []
                keyUp.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                keyUp.post(tap: .cghidEventTap)
            }
            usleep(4_000) // small gap so slow apps don't drop characters
            index += chunkSize
        }
    }

    // MARK: - Clipboard snapshot/restore

    private struct PasteboardItemSnapshot {
        let typeData: [(NSPasteboard.PasteboardType, Data)]
    }

    private func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [PasteboardItemSnapshot] {
        // Cap per-representation size so an enormous clipboard item (e.g. a large
        // uncompressed image) can't bloat the snapshot or stall the paste. Smaller
        // representations of the same content are still captured, so restore usually survives.
        let maxBytes = 20 * 1024 * 1024
        return (pasteboard.pasteboardItems ?? []).map { item in
            PasteboardItemSnapshot(
                typeData: item.types.compactMap { type in
                    guard let data = item.data(forType: type), data.count <= maxBytes else { return nil }
                    return (type, data)
                }
            )
        }
    }

    private func restorePasteboard(_ snapshot: [PasteboardItemSnapshot], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let items = snapshot.map { snap -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in snap.typeData {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }
}
