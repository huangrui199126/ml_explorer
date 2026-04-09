import SwiftUI

struct MLChallengesListView: View {
    @StateObject private var vm = MLChallengesViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground))

                categoryBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))

                Divider()

                if vm.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if vm.filtered.isEmpty {
                    emptyState
                } else {
                    challengeList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ML Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vm.searchText, prompt: "Search challenges…")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(vm.filtered.count) of \(vm.problems.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { vm.load() }
    }

    // MARK: - Difficulty Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                diffChip(label: "All", icon: "list.bullet", color: .primary, active: vm.selectedDifficulty == nil) {
                    vm.selectedDifficulty = nil
                }
                diffChip(label: "Easy", icon: "checkmark.circle", color: .green, active: vm.selectedDifficulty == "easy") {
                    vm.selectedDifficulty = vm.selectedDifficulty == "easy" ? nil : "easy"
                }
                diffChip(label: "Medium", icon: "minus.circle", color: .orange, active: vm.selectedDifficulty == "medium") {
                    vm.selectedDifficulty = vm.selectedDifficulty == "medium" ? nil : "medium"
                }
                diffChip(label: "Hard", icon: "xmark.circle", color: .red, active: vm.selectedDifficulty == "hard") {
                    vm.selectedDifficulty = vm.selectedDifficulty == "hard" ? nil : "hard"
                }
            }
        }
    }

    // MARK: - Category Bar

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                catChip(label: "All", active: vm.selectedCategory == nil) { vm.selectedCategory = nil }
                ForEach(vm.categories, id: \.self) { cat in
                    catChip(label: cat, active: vm.selectedCategory == cat) {
                        vm.selectedCategory = vm.selectedCategory == cat ? nil : cat
                    }
                }
            }
        }
    }

    // MARK: - List

    private var challengeList: some View {
        List {
            ForEach(vm.filtered) { challenge in
                NavigationLink(destination: MLChallengeDetailView(challenge: challenge)) {
                    MLChallengeRow(challenge: challenge)
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Challenges Found",
            systemImage: "brain",
            description: Text("Try adjusting your search or filters.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Chip Helpers

    private func diffChip(label: String, icon: String, color: Color, active: Bool, action: @escaping () -> Void) -> some View {
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

    private func catChip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(active ? .semibold : .regular)
                .foregroundStyle(active ? Color.blue : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(active ? Color.blue.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MLChallengeRow

struct MLChallengeRow: View {
    let challenge: MLChallenge

    var body: some View {
        HStack(spacing: 12) {
            // Number badge
            Text("#\(challenge.id)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    // Difficulty pill
                    Text(challenge.difficultyLabel)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(challenge.difficultyColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(challenge.difficultyColor.opacity(0.12), in: Capsule())

                    // Category tag
                    Text(challenge.category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
