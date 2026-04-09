import SwiftUI

struct MLChallengeDetailView: View {
    let challenge: MLChallenge
    @State private var selectedTab = 0
    @State private var showPaywall = false
    @StateObject private var svc = SubscriptionService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerSection
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                // Tab picker
                Picker("Tab", selection: $selectedTab) {
                    Text("Problem").tag(0)
                    Text("Example").tag(1)
                    Text("Learn").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // Tab content
                switch selectedTab {
                case 0: problemTab
                case 1: exampleTab
                case 2: learnTab
                default: EmptyView()
                }
            }
        }
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = challenge.description
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 8) {
            Text(challenge.difficultyLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(challenge.difficultyColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(challenge.difficultyColor.opacity(0.12), in: Capsule())

            Text(challenge.category)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.tertiarySystemGroupedBackground), in: Capsule())

            Spacer()

            Text("#\(challenge.id)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Problem Tab

    private var problemTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(challenge.description)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .padding(.horizontal, 16)

            if !challenge.starterCode.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Starter Code")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(challenge.starterCode)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - Example Tab

    private var exampleTab: some View {
        VStack(spacing: 12) {
            exampleCard(title: "Input", icon: "arrow.right.circle", color: .blue, content: challenge.example.input)
            exampleCard(title: "Output", icon: "arrow.left.circle", color: .green, content: challenge.example.output)
            exampleCard(title: "Reasoning", icon: "lightbulb", color: .orange, content: challenge.example.reasoning)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    private func exampleCard(title: String, icon: String, color: Color, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            Text(content)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Learn Tab

    private var learnTab: some View {
        Group {
            if svc.isPro {
                learnContent
            } else {
                learnPaywall
            }
        }
    }

    private var learnContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let attributed = try? AttributedString(markdown: challenge.learnSection) {
                Text(attributed)
                    .font(.body)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            } else {
                Text(challenge.learnSection)
                    .font(.body)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var learnPaywall: some View {
        ZStack {
            // Blurred preview
            Text(challenge.learnSection.prefix(400))
                .font(.body)
                .lineSpacing(4)
                .padding(.horizontal, 16)
                .blur(radius: 6)
                .allowsHitTesting(false)

            // Overlay
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                Text("Pro Feature")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Unlock detailed explanations, math breakdowns, and algorithm walkthroughs for every challenge.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    showPaywall = true
                } label: {
                    Text("Unlock ML Explorer Pro")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            LinearGradient(colors: [.purple, .blue],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 32)
    }
}
