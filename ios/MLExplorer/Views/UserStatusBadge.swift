import SwiftUI

// MARK: - UserStatusBadge
// Small persistent pill shown in the nav bar so the user always knows their plan.

struct UserStatusBadge: View {
    @ObservedObject private var svc     = SubscriptionService.shared
    @ObservedObject private var credits = FreeCreditsService.shared
    @State private var showPaywall = false

    var body: some View {
        Button { if !svc.isPro { showPaywall = true } } label: {
            badge
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    @ViewBuilder
    private var badge: some View {
        if svc.isPro {
            proBadge
        } else {
            freeBadge
        }
    }

    // ── Pro badge ───────────────────────────────────────────────────────────

    private var proBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
            Text("PRO")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            LinearGradient(
                colors: [Color(hex: "7B2FF7"), Color(hex: "2196F3")],
                startPoint: .leading, endPoint: .trailing
            ),
            in: Capsule()
        )
        .shadow(color: .purple.opacity(0.35), radius: 4, x: 0, y: 2)
    }

    // ── Free badge ──────────────────────────────────────────────────────────

    private var freeBadge: some View {
        HStack(spacing: 4) {
            creditDots
            Text(badgeLabel)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(badgeForeground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(badgeBackground, in: Capsule())
    }

    private var creditDots: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i < credits.remainingCredits ? dotActiveColor : Color.secondary.opacity(0.25))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var badgeLabel: String {
        switch credits.remainingCredits {
        case 0:  return "Upgrade"
        case 1:  return "1 preview left"
        default: return "\(credits.remainingCredits) previews left"
        }
    }

    private var dotActiveColor: Color {
        credits.remainingCredits == 0 ? .clear : .orange
    }

    private var badgeForeground: Color {
        credits.remainingCredits == 0 ? .white : .orange
    }

    private var badgeBackground: some ShapeStyle {
        if credits.remainingCredits == 0 {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "7B2FF7"), Color(hex: "2196F3")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
        } else {
            return AnyShapeStyle(Color.orange.opacity(0.12))
        }
    }
}

// MARK: - CreditStatusBanner
// Shown inside PaperDetailView just above the deep insight card.
// Reminds free users of their credit status without being intrusive.

struct CreditStatusBanner: View {
    @ObservedObject private var svc     = SubscriptionService.shared
    @ObservedObject private var credits = FreeCreditsService.shared
    @State private var showPaywall = false

    var body: some View {
        if svc.isPro { EmptyView() }
        else { banner }
    }

    private var banner: some View {
        HStack(spacing: 10) {
            // Credit pip row
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < credits.remainingCredits
                              ? Color.orange
                              : Color.secondary.opacity(0.2))
                        .frame(width: 18, height: 6)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(titleText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(titleColor)
                Text(subtitleText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showPaywall = true
            } label: {
                Text(credits.remainingCredits == 0 ? "Upgrade" : "Go Pro")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "7B2FF7"), Color(hex: "2196F3")],
                            startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            credits.remainingCredits == 0
                            ? Color.purple.opacity(0.4)
                            : Color.orange.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var titleText: String {
        switch credits.remainingCredits {
        case 0:  return "Free previews used up"
        case 1:  return "Last free preview this month"
        case 2:  return "2 free previews remaining"
        default: return "3 free previews this month"
        }
    }

    private var subtitleText: String {
        credits.remainingCredits == 0
            ? "Upgrade to unlock all papers"
            : "Resets monthly · Pro unlocks all"
    }

    private var titleColor: Color {
        credits.remainingCredits == 0 ? .purple : .orange
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
