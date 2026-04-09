import SwiftUI

@main
struct MLExplorerApp: App {
    @StateObject private var insightStore = InsightStore()
    @StateObject private var questionStore = QuestionStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            PaperListView()
                .environmentObject(insightStore)
                .environmentObject(questionStore)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Re-check monthly reset every time app comes to foreground.
                // Handles the case where the app stays open across a month boundary.
                Task { await FreeCreditsService.shared.refreshIfNeeded() }
            }
        }
    }
}
