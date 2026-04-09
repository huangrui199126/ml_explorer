import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var svc = SubscriptionService.shared
    @State private var showPaywall = false
    #if DEBUG
    @ObservedObject private var credits = FreeCreditsService.shared
    #endif

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Subscription
                Section {
                    if svc.isPro {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.purple)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ML Explorer Pro")
                                    .fontWeight(.semibold)
                                Text("All features unlocked")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)

                        Button("Manage Subscription") {
                            if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundStyle(.blue)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "brain.head.profile")
                                    .foregroundStyle(.purple)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Pro")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    Text("Deep insights · Interview prep · Notes · PDF")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }

                        Button("Restore Purchases") {
                            Task { await svc.restore() }
                        }
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Subscription")
                }

                #if DEBUG
                // MARK: Debug (only visible in DEBUG builds)
                Section("Debug") {
                    Toggle("Force Pro", isOn: Binding(
                        get: { svc.isPro },
                        set: { svc.overridePro($0) }
                    ))
                    LabeledContent("Free Credits Left", value: "\(credits.remainingCredits)")
                }
                #endif

                // MARK: About
                Section("About") {
                    LabeledContent("App Version", value: "1.0")
                    LabeledContent("Papers Source", value: "GitHub Pages (weekly)")
                    LabeledContent("AI Insights", value: "Pre-generated · 6,000+ papers")
                    Link("Privacy Policy",
                         destination: URL(string: "https://huangrui199126.github.io/ml_explorer/privacy.html")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}
