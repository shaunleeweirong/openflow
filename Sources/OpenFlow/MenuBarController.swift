import AppKit

enum AppState: Equatable {
    case downloadingModel
    case loadingModel
    case ready
    case recording
    case transcribing
    case error(String)

    var statusText: String {
        switch self {
        case .downloadingModel: return "Downloading model (~1 GB, one-time)…"
        case .loadingModel: return "Loading model…"
        case .ready: return "Ready — hold your hotkey to dictate"
        case .recording: return "Recording…"
        case .transcribing: return "Transcribing…"
        case .error(let message): return "Error: \(message)"
        }
    }

    var symbolName: String {
        switch self {
        case .downloadingModel, .loadingModel: return "arrow.down.circle"
        case .ready: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .error: return "exclamationmark.triangle"
        }
    }
}

final class MenuBarController {
    private let statusItem: NSStatusItem
    private let statusMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let lastTranscriptItem = NSMenuItem(title: "No dictations yet", action: nil, keyEquivalent: "")

    var onOpenSettings: (() -> Void)?
    var onOpenPermissions: (() -> Void)?
    var onCopyLastTranscript: (() -> Void)?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        lastTranscriptItem.isEnabled = false
        menu.addItem(lastTranscriptItem)
        let copyItem = NSMenuItem(title: "Copy Last Transcript", action: #selector(copyLast), keyEquivalent: "c")
        copyItem.target = self
        menu.addItem(copyItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let permissionsItem = NSMenuItem(title: "Permissions & Setup…", action: #selector(openPermissions), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit OpenFlow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        setState(.loadingModel)
    }

    func setState(_ state: AppState) {
        statusMenuItem.title = state.statusText
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: state.statusText)
        image?.isTemplate = true
        button.image = image
        button.contentTintColor = {
            switch state {
            case .recording: return .systemRed
            case .transcribing: return .systemOrange
            case .error: return .systemYellow
            default: return nil
            }
        }()
    }

    func setLastTranscript(_ text: String) {
        let trimmed = text.count > 60 ? String(text.prefix(60)) + "…" : text
        lastTranscriptItem.title = trimmed.isEmpty ? "No dictations yet" : "“\(trimmed)”"
    }

    @objc private func openSettings() { onOpenSettings?() }
    @objc private func openPermissions() { onOpenPermissions?() }
    @objc private func copyLast() { onCopyLastTranscript?() }
}
