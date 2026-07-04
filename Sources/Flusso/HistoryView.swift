import FlussoCore
import SwiftUI

struct HistoryView: View {
    @ObservedObject var state: AppState
    @State private var records: [DictationRecord] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            List(Array(records.enumerated()), id: \.offset) { _, record in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        if let transcribeMs = record.transcribeMs, let cleanMs = record.cleanMs {
                            Text(timingLabel(transcribeMs: transcribeMs, cleanMs: cleanMs))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    Text(record.cleaned)
                    HStack {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(record.cleaned, forType: .string)
                        }
                        if record.raw != record.cleaned {
                            Text("raw: \(record.raw)").font(.caption2)
                                .foregroundStyle(.tertiary).lineLimit(1)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            HStack {
                Text("\(state.history.count) dictations in the local corpus").font(.caption)
                Spacer()
                Button("Delete All", role: .destructive) {
                    try? state.history.deleteAll()
                    records = []
                }
            }
        }
        .padding()
        .frame(width: 480, height: 460)
        .onAppear { records = state.history.recent(20) }
        .onChange(of: state.phase) { _, newPhase in
            if newPhase == .idle { records = state.history.recent(20) }
        }
    }

    private func timingLabel(transcribeMs: Int, cleanMs: Int) -> String {
        String(format: "%.1f s + %.1f s", Double(transcribeMs) / 1000, Double(cleanMs) / 1000)
    }
}
