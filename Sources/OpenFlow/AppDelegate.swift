import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var hotkey: HotkeyManager!
    private let capture = AudioCapture()
    private let engine: ASREngine = ParakeetEngine()
    private let injector = TextInjector()
    private let permissions = PermissionsManager()
    private let settings = SettingsStore.shared
    private let enhancer: Enhancer? = {
        if #available(macOS 26, *) { return AppleFoundationEnhancer() }
        return nil
    }()

    private let stats = StatsStore.shared
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var insightsWindow: NSWindow?
    private var toastWindow: NSWindow?
    private var toastDismiss: DispatchWorkItem?
    private var pendingTargetBundleID: String?
    private var pendingTargetName: String?
    private var cancellables = Set<AnyCancellable>()
    private var lastTranscript = ""
    private var lastRawTranscript = ""

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
        menuBar.onCopyRawTranscript = { [weak self] in
            guard let self, !self.lastRawTranscript.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(self.lastRawTranscript, forType: .string)
        }
        menuBar.onOpenInsights = { [weak self] in self?.showInsights() }

        stats.onAchievementUnlocked = { [weak self] achievement in
            self?.showAchievementToast(achievement)
        }
        // Keep the menu's usage summary current — fires on every record and on reset.
        stats.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snap in
                self?.menuBar.setStatsSummary(StatsStore.summaryText(for: snap))
            }
            .store(in: &cancellables)

        engine.onStateChange = { [weak self] state in
            DispatchQueue.main.async { self?.handleEngineState(state) }
        }

        hotkey = HotkeyManager(
            onKeyDown: { [weak self] in self?.startDictation() },
            onKeyUp: { [weak self] in self?.finishDictation() }
        )

        // Kick off model download/load in the background right away.
        Task { try? await engine.prepare() }
        // Warm the on-device LLM only when AI cleanup is on — no point loading a ~3B model
        // (or contending for the Neural Engine) when the enhancer won't run.
        if settings.aiEnhance { enhancer?.prewarm() }

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
        // At hotkey-down the frontmost app is the one being dictated into (OpenFlow is a
        // menu-bar app and doesn't take focus). Capture it now for the per-app breakdown.
        let front = NSWorkspace.shared.frontmostApplication
        pendingTargetBundleID = front?.bundleIdentifier
        pendingTargetName = front?.localizedName

        do {
            try capture.start()
            menuBar.setState(.recording)
            // Re-warm while the user speaks so the LLM is hot by key-release — only when
            // AI cleanup is on, so the instant rule-based path never loads the model.
            if settings.aiEnhance { enhancer?.prewarm() }
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
                let pipeline = EnhancementPipeline(
                    enhancer: self.enhancer,
                    aiEnhanceEnabled: self.settings.aiEnhance,
                    removeFillers: self.settings.removeFillers,
                    dictionary: self.settings.dictionaryEntries
                )
                let cleaned = await pipeline.run(raw)
                await MainActor.run {
                    self.lastRawTranscript = raw
                    self.lastTranscript = cleaned
                    self.menuBar.setLastTranscript(cleaned)
                    if !cleaned.isEmpty {
                        self.injector.inject(
                            cleaned,
                            mode: self.settings.injectionMode,
                            restoreClipboard: self.settings.restoreClipboard
                        )
                        self.recordStats(for: cleaned, samples: samples)
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

    private func showInsights() {
        if insightsWindow == nil {
            let view = InsightsView(stats: stats)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "OpenFlow Insights"
            window.contentView = NSHostingView(rootView: view)
            window.isReleasedWhenClosed = false
            window.center()
            insightsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        insightsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Stats

    private func recordStats(for text: String, samples: [Float]) {
        guard settings.statsEnabled else { return }
        let event = DictationEvent(
            date: Date(),
            wordCount: WordCounter.count(text),
            spokenSeconds: Double(samples.count) / AudioCapture.targetSampleRate,
            appBundleID: settings.perAppTracking ? pendingTargetBundleID : nil,
            appName: settings.perAppTracking ? pendingTargetName : nil
        )
        stats.record(event)
    }

    /// A permission-free celebration: a borderless, non-activating floating window shown
    /// top-center that auto-dismisses. No `UNUserNotification`, so no permission prompt and no
    /// focus stolen from the app the user is working in.
    private func showAchievementToast(_ achievement: Achievement) {
        let host = NSHostingView(rootView: AchievementToastView(achievement: achievement))
        let size = host.fittingSize

        let window: NSWindow
        if let existing = toastWindow {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            toastWindow = window
        }
        window.contentView = host
        window.setContentSize(size)

        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: vf.midX - size.width / 2, y: vf.maxY - size.height - 12))
        }
        window.orderFrontRegardless()

        toastDismiss?.cancel()
        let work = DispatchWorkItem { [weak window] in window?.orderOut(nil) }
        toastDismiss = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: work)
    }
}
