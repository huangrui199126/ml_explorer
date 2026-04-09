import SwiftUI

struct NoteEditorView: View {
    let paper: Paper
    @EnvironmentObject var insightStore: InsightStore
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Paper context header
                VStack(alignment: .leading, spacing: 4) {
                    Text(paper.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    if let topic = paper.topic {
                        Text(topic)
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))

                Divider()

                TextEditor(text: $text)
                    .font(.body)
                    .padding(12)
                    .focused($focused)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Write your notes, key takeaways, questions…")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        insightStore.saveNote(paperId: paper.id, content: text)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text == (insightStore.note(for: paper)?.content ?? ""))
                }
            }
        }
        .onAppear {
            text = insightStore.note(for: paper)?.content ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
        }
    }
}

// MARK: - Compact note preview (shown in detail view)

struct NotePreviewCard: View {
    let paper: Paper
    @EnvironmentObject var insightStore: InsightStore
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionHeader("My Notes", icon: "note.text", color: .yellow)
                Spacer()
                Button(hasNote ? "Edit" : "Add Note") { showEditor = true }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            .padding(.bottom, 8)

            if let note = insightStore.note(for: paper), !note.content.isEmpty {
                Text(note.content)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(4)
                    .onTapGesture { showEditor = true }

                Text("Edited \(note.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                Button {
                    showEditor = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("Add your notes, questions, or key takeaways")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $showEditor) {
            NoteEditorView(paper: paper)
                .environmentObject(insightStore)
        }
    }

    private var hasNote: Bool {
        !(insightStore.note(for: paper)?.content.isEmpty ?? true)
    }
}
