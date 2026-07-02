import SwiftUI

struct OnboardingView: View {
    @ObservedObject var permissions: PermissionsManager
    let engineStateProvider: () -> ASRModelState
    let onDone: () -> Void

    @State private var engineState: ASRModelState = .notLoaded
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to OpenFlow")
                    .font(.title2.bold())
                Text("Hold **⌥ Option + Space**, speak, release — your words are typed wherever your cursor is. Everything runs on this Mac; audio never leaves your machine.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                permissionRow(
                    granted: permissions.micGranted,
                    title: "Microphone",
                    detail: "Needed to hear you.",
                    buttonTitle: "Allow Microphone",
                    action: {
                        permissions.requestMicrophone()
                        permissions.openMicrophoneSettings()
                    }
                )
                permissionRow(
                    granted: permissions.accessibilityGranted,
                    title: "Accessibility",
                    detail: "Needed to type text into other apps.",
                    buttonTitle: "Open Settings",
                    action: {
                        permissions.promptAccessibility()
                        permissions.openAccessibilitySettings()
                    }
                )
                modelRow
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.windowBackgroundColor)))

            Spacer()

            HStack {
                Spacer()
                Button("Done") { onDone() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!permissions.allGranted || engineState != .ready)
            }
        }
        .padding(24)
        .frame(width: 460, height: 420)
        .onReceive(timer) { _ in
            permissions.refresh()
            engineState = engineStateProvider()
        }
        .onAppear {
            permissions.refresh()
            engineState = engineStateProvider()
        }
    }

    private var modelRow: some View {
        HStack(alignment: .top, spacing: 10) {
            statusIcon(engineState == .ready)
            VStack(alignment: .leading, spacing: 2) {
                Text("Speech model").fontWeight(.medium)
                Text(engineState.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if engineState != .ready {
                ProgressView().controlSize(.small)
            }
        }
    }

    private func permissionRow(
        granted: Bool,
        title: String,
        detail: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            statusIcon(granted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button(buttonTitle, action: action)
            }
        }
    }

    private func statusIcon(_ ok: Bool) -> some View {
        Image(systemName: ok ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(ok ? .green : .secondary)
            .font(.title3)
    }
}
