import FlussoCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var models: [String] = []
    @State private var modelError: String?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Start Flusso at login", isOn: $state.settings.launchAtLogin)
                    .onChange(of: state.settings.launchAtLogin) { _, on in
                        if on { try? SMAppService.mainApp.register() }
                        else { try? SMAppService.mainApp.unregister() }
                    }
            }
            Section("AI cleanup") {
                Toggle("Clean up dictation with a local AI model", isOn: $state.settings.cleanupEnabled)
                Picker("Ollama model", selection: $state.settings.ollamaModel) {
                    ForEach(models.isEmpty ? [state.settings.ollamaModel] : models, id: \.self) {
                        Text($0)
                    }
                }
                TextField("Ollama endpoint", text: $state.settings.ollamaEndpoint)
                if let modelError {
                    Text(modelError).font(.caption).foregroundStyle(.secondary)
                }
                Button("Refresh model list") { Task { await loadModels() } }
            }
            Section("Privacy") {
                Toggle("Keep audio recordings in the local corpus", isOn: $state.settings.storeAudio)
                Text("Everything stays on this Mac. The corpus builds your private voice dataset.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .task { await loadModels() }
    }

    private func loadModels() async {
        guard let url = URL(string: state.settings.ollamaEndpoint) else { return }
        do {
            models = try await OllamaClient(endpoint: url).listModels()
            modelError = nil
        } catch {
            models = []
            modelError = "Ollama not reachable. Install models with: ollama pull <name>"
        }
    }
}
