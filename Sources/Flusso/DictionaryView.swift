import SwiftUI

struct DictionaryView: View {
    @ObservedObject var state: AppState
    @State private var newTerm = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Words Flusso must always spell correctly.").font(.caption)
            List {
                ForEach(state.dictionary.terms, id: \.self) { term in
                    HStack {
                        Text(term)
                        Spacer()
                        Button(role: .destructive) { state.dictionary.remove(term) }
                            label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
            }
            HStack {
                TextField("Add a word or name", text: $newTerm)
                    .onSubmit(add)
                Button("Add", action: add)
            }
        }
        .padding()
        .frame(width: 360, height: 420)
    }

    private func add() {
        state.dictionary.add(newTerm)
        newTerm = ""
    }
}
