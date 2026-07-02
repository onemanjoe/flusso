import SwiftUI

struct OnboardingView: View {
    @ObservedObject var state: AppState
    @State private var mic = Permissions.microphoneGranted
    @State private var ax = Permissions.accessibilityGranted
    @State private var input = Permissions.inputMonitoringGranted
    @State private var preparing = false
    @State private var engineReady = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Flusso setup").font(.title2.bold())
            Text("Three permissions, everything stays on this Mac.").font(.caption)

            row(done: mic, title: "Microphone", detail: "To hear your dictation.") {
                Task { mic = await Permissions.requestMicrophone() }
            }
            row(done: input, title: "Input Monitoring", detail: "To notice when you hold the Fn key.") {
                Permissions.requestInputMonitoring()
                Permissions.openPrivacyPane("Privacy_ListenEvent")
            }
            row(done: ax, title: "Accessibility", detail: "To paste the text where your cursor is.") {
                Permissions.openPrivacyPane("Privacy_Accessibility")
            }

            Divider()
            HStack {
                Image(systemName: engineReady ? "checkmark.circle.fill" : "arrow.down.circle")
                    .foregroundStyle(engineReady ? .green : .secondary)
                VStack(alignment: .leading) {
                    Text("Speech model")
                    Text("Parakeet V3, about 600 MB, downloaded once.").font(.caption)
                }
                Spacer()
                Button(preparing ? "Preparing..." : "Download and start") {
                    preparing = true
                    Task {
                        await state.startEngines()
                        engineReady = state.engine.isReady
                        preparing = false
                    }
                }
                .disabled(preparing || engineReady)
            }
            Text("If a permission does not stick, quit Flusso and reopen it.").font(.caption2)
        }
        .padding(20)
        .frame(width: 440)
        .onReceive(timer) { _ in
            mic = Permissions.microphoneGranted
            ax = Permissions.accessibilityGranted
            input = Permissions.inputMonitoringGranted
        }
    }

    @ViewBuilder
    private func row(done: Bool, title: String, detail: String,
                     action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption)
            }
            Spacer()
            Button("Grant", action: action).disabled(done)
        }
    }
}
