import SwiftUI

struct MemoryAddView: View {
    let onAdd: (String, AIMemoryCategory) -> Void
    @State private var content = ""
    @State private var selectedCategory: AIMemoryCategory = .custom
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Memory")
                .font(.headline)

            TextEditor(text: $content)
                .font(.body)
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Category")
                    .font(.subheadline.weight(.medium))
                Picker("Category", selection: $selectedCategory) {
                    ForEach(AIMemoryCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    onAdd(content, selectedCategory)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
