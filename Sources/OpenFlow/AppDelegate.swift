import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var hotkey: HotkeyManager!
    private let capture = AudioCapture()
    private let engine: ASREngine = ParakeetEngine()
    private let injector = TextInjector()
    private let permissions = PermissionsManager()
    private let settings = SettingsStore.shared

    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var lastTranscript = ""

    // Ignore accidental taps shorter than this many 16 kHz samples (~0.3 s).
    private let minimumSamples = 4_800

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController()
        menuBar.onOpenSettings = { [weak self] in self?.showSettings() }
        menuBar.onOpenPermissions = { [weak self] in self?.showOnboarding() }
        menuBar.onCopyLastTranscript = { [weak self] in
            guard let self, !self.lastTranscript.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(self.lastTranscript, forType: .string)
        }

        engine.onStateChange = { [weak self] state in
            DispatchQueue.main.async { self?.handleEngineState(state) }
        }

        hotkey = HotkeyManager(
            onKeyDown: { [weak self] in self?.startDictation() },
            onKeyUp: { [weak self] in self?.finishDictation() }
        )

        // Kick off model download/load in the background right away.
        Task { try? await engine.prepare() }

        permissions.refresh()
        if !permissions.allGranted || !settings.onboardingCompleted {
            showOnboarding()
        }
    }

    // MARK: - Dictation pipeline

    private func startDictation() {
        guard engine.state == .ready, !capture.isRecording else {
            if engine.state != .ready { NSSound.beep() }
            return
        }
        permissions.refresh()
        guard permissions.micGranted else {
            NSSound.beep()
            showOnboarding()
            return
        }
        do {
            try capture.start()
            menuBar.setState(.recording)
            playSound("Pop")
        } catch {
            menuBar.setState(.error(error.localizedDescription))
        }
    }

    private func finishDictation() {
        guard capture.isRecording else { return }
        let samples = capture.stop()
        playSound("Bottle")

        guard samples.count >= minimumSamples else {
            menuBar.setState(.ready)
            return
        }

        menuBar.setState(.transcribing)
        Task { [weak self] in
            guard let self else { return }
            do {
                let raw = try await self.engine.transcribe(samples: samples)
                let processor = TextProcessor(
                    removeFillers: self.settings.removeFillers,
                    dictionary: self.settings.dictionaryEntries
                )
                let cleaned = processor.process(raw)
                await MainActor.run {
                    self.lastTranscript = cleaned
                    self.menuBar.setLastTranscript(cleaned)
                    if !cleaned.isEmpty {
                        self.injector.inject(
                            cleaned,
                            mode: self.settings.injectionMode,
                            restoreClipboard: self.settings.restoreClipboard
                        )
                    }
                    self.menuBar.setState(.ready)
                }
            } catch {
                await MainActor.run {
                    self.menuBar.setState(.error(error.localizedDescription))
                }
            }
        }
    }

    private func handleEngineState(_ state: ASRModelState) {
        switch state {
        case .notLoaded, .downloading: menuBar.setState(.downloadingModel)
        case .loading: menuBar.setState(.loadingModel)
        case .ready: menuBar.setState(.ready)
        case .failed(let message): menuBar.setState(.error(message))
        }
    }

    private func playSound(_ name: String) {
        guard settings.playSounds else { return }
        NSSound(named: name)?.play()
    }

    // MARK: - Windows

    private func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "OpenFlow Settings"
            window.contentView = NSHostingView(rootView: view)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            let view = OnboardingView(
                permissions: permissions,
                engineStateProvider: { [weak self] in self?.engine.state ?? .notLoaded },
                onDone: { [weak self] in
                    self?.settings.onboardingCompleted = true
                    self?.onboardingWindow?.close()
                }
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to OpenFlow"
            window.contentView = NSHostingView(rootView: view)
            window.isReleasedWhenClosed = false
            window.center()
            onboardingWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }
}
