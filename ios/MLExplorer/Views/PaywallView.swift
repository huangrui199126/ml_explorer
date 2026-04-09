import SwiftUI
import StoreKit

// MARK: - PaywallView

struct PaywallView: View {
    @StateObject private var svc = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int = 1   // default: annual

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 8)

                    featuresSection
                        .padding(.top, 28)

                    planPicker
                        .padding(.top, 28)
                        .padding(.horizontal, 20)

                    ctaButton
                        .padding(.top, 20)
                        .padding(.horizontal, 20)

                    restoreButton
                        .padding(.top, 12)

                    legalText
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
        .task { await svc.refresh() }
        .onChange(of: svc.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.purple.opacity(0.25), .blue.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 90, height: 90)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 38))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            Text("ML Explorer Pro")
                .font(.title2)
                .fontWeight(.bold)

            Text("Deep insights & interview prep\nfor every ML paper.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(ProFeature.allCases) { feature in
                FeatureRow(feature: feature)
                if feature != ProFeature.allCases.last {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }

    // MARK: - Plan Picker

    private var planPicker: some View {
        VStack(spacing: 10) {
            if svc.products.isEmpty {
                if svc.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    Text("Plans unavailable")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
            } else {
                ForEach(Array(svc.products.enumerated()), id: \.element.id) { idx, product in
                    PlanCard(
                        product: product,
                        monthly: svc.products.first(where: \.isMonthly),
                        isSelected: selectedIndex == idx
                    )
                    .onTapGesture { selectedIndex = idx }
                }
            }
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            guard svc.products.indices.contains(selectedIndex) else { return }
            let product = svc.products[selectedIndex]
            Task { await svc.purchase(product) }
        } label: {
            Group {
                if svc.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(ctaTitle)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(colors: [.purple, .blue],
                               startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(svc.isLoading || svc.products.isEmpty)
    }

    private var ctaTitle: String {
        guard svc.products.indices.contains(selectedIndex) else { return "Subscribe" }
        let p = svc.products[selectedIndex]
        // Show free trial label when annual has an introductory offer
        if p.isAnnual, let intro = p.subscription?.introductoryOffer, intro.price == 0 {
            let days = intro.period.value * (intro.period.unit == .day ? 1 : 7)
            return "Try Free for \(days) Days"
        }
        return "Start for \(p.displayPrice)\(p.isMonthly ? "/month" : "/year")"
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await svc.restore() }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    // MARK: - Legal

    private var legalText: some View {
        VStack(spacing: 6) {
            Text("Payment charged to your Apple ID account. Subscription renews automatically unless cancelled at least 24 hours before the end of the period. Manage in App Store settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Link("Privacy Policy", destination: URL(string: "https://huangrui199126.github.io/ml_explorer/privacy.html")!)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let feature: ProFeature

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.system(size: 18))
                .foregroundStyle(feature.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(feature.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - PlanCard

private struct PlanCard: View {
    let product: Product
    let monthly: Product?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Radio circle
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.purple : Color.secondary.opacity(0.4), lineWidth: 2)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 13, height: 13)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(product.isMonthly ? "Monthly (1 month)" : "Annual (1 year)")
                        .fontWeight(.semibold)

                    if product.isAnnual, let m = monthly {
                        Text(product.savingsLabel(monthly: m))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.green, in: Capsule())
                    }
                }

                if product.isAnnual, let perMonth = product.annualPerMonthString {
                    Text(perMonth)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(product.isMonthly ? "\(product.displayPrice) per month" : "\(product.displayPrice) per year")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(product.isMonthly
                 ? "\(product.displayPrice)/mo"
                 : "\(product.displayPrice)/yr")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .purple : .primary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
                )
        )
    }
}

// MARK: - ProFeature

enum ProFeature: String, CaseIterable, Identifiable {
    case deepAnalysis   = "Deep Analysis"
    case interviewPrep  = "Interview Prep"
    case tracker        = "Question Tracker"
    case notes          = "Paper Notes"
    case pdfReader      = "PDF Reader"
    case bookmarks      = "Unlimited Bookmarks"

    var id: String { rawValue }

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .deepAnalysis:  return "Method breakdown, innovations & limitations"
        case .interviewPrep: return "5 Q&As generated for every paper"
        case .tracker:       return "Track New → Learning → Mastered"
        case .notes:         return "Write and save notes on any paper"
        case .pdfReader:     return "Read the full paper in-app"
        case .bookmarks:     return "Bookmark as many papers as you want"
        }
    }

    var icon: String {
        switch self {
        case .deepAnalysis:  return "brain.head.profile"
        case .interviewPrep: return "person.fill.questionmark"
        case .tracker:       return "chart.bar.fill"
        case .notes:         return "note.text"
        case .pdfReader:     return "doc.richtext"
        case .bookmarks:     return "bookmark.fill"
        }
    }

    var color: Color {
        switch self {
        case .deepAnalysis:  return .purple
        case .interviewPrep: return .teal
        case .tracker:       return .blue
        case .notes:         return .orange
        case .pdfReader:     return .indigo
        case .bookmarks:     return .pink
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
