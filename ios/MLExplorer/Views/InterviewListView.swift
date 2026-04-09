import SwiftUI

struct InterviewListView: View {
    @EnvironmentObject var questionStore: QuestionStore
    @State private var filter: QuestionStatus? = nil  // nil = All
    @State private var expandedID: UUID? = nil
    @Environment(\.dismiss) private var dismiss

    private var filtered: [SavedQuestion] {
        let all = questionStore.questions.sorted { $0.savedAt > $1.savedAt }
        guard let f = filter else { return all }
        return all.filter { $0.status == f }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status filter bar
                filterBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground))

                Divider()

                if filtered.isEmpty {
                    emptyState
                } else {
                    questionList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Interview Prep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    statsLabel
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", icon: "list.bullet",
                           color: .primary, active: filter == nil) {
                    filter = nil
                }
                ForEach(QuestionStatus.allCases, id: \.self) { status in
                    let count = questionStore.questions.filter { $0.status == status }.count
                    filterChip(label: "\(status.rawValue) (\(count))", icon: status.icon,
                               color: status.color, active: filter == status) {
                        filter = (filter == status) ? nil : status
                    }
                }
            }
        }
    }

    private func filterChip(label: String, icon: String, color: Color,
                             active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .fontWeight(active ? .semibold : .regular)
                .foregroundStyle(active ? color : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? color.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Question List

    private var questionList: some View {
        List {
            ForEach(filtered) { q in
                QuestionRow(q: q, isExpanded: expandedID == q.id) {
                    withAnimation(.spring(duration: 0.25)) {
                        expandedID = expandedID == q.id ? nil : q.id
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        questionStore.delete(q.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        questionStore.advanceStatus(q.id)
                    } label: {
                        Label(q.status.next.rawValue, systemImage: q.status.next.icon)
                    }
                    .tint(q.status.next.color)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label(filter == nil ? "No Saved Questions" : "No \(filter!.rawValue) Questions",
                  systemImage: filter == nil ? "bookmark" : filter!.icon)
        } description: {
            Text(filter == nil
                 ? "Open any paper → tap Interview Prep → tap the bookmark icon on a question to save it here."
                 : "No questions with '\(filter!.rawValue)' status yet.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Stats

    private var statsLabel: some View {
        HStack(spacing: 10) {
            statDot(count: questionStore.newCount,      color: .orange)
            statDot(count: questionStore.learningCount, color: .blue)
            statDot(count: questionStore.masteredCount, color: .green)
        }
    }

    private func statDot(count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(count)").font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Question Row

struct QuestionRow: View {
    let q: SavedQuestion
    let isExpanded: Bool
    let onTap: () -> Void
    @EnvironmentObject var questionStore: QuestionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 10) {
                    // Status badge
                    Image(systemName: q.status.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(q.status.color)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(q.question)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        Text(q.paperTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().padding(.horizontal, 12)

                    Text(q.answer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 44)
                        .padding(.bottom, 4)

                    // Status picker
                    HStack(spacing: 6) {
                        Spacer()
                        ForEach(QuestionStatus.allCases, id: \.self) { status in
                            Button {
                                questionStore.setStatus(q.id, status: status)
                            } label: {
                                Label(status.rawValue, systemImage: status.icon)
                                    .font(.caption)
                                    .fontWeight(q.status == status ? .semibold : .regular)
                                    .foregroundStyle(q.status == status ? status.color : .secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        q.status == status ? status.color.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
