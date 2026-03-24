import Foundation

/// Tracks free-tier usage limits, reset each calendar month.
///   - Deep insights:       3 / month
///   - Mock interview sessions: 5 / month
/// Persisted in UserDefaults.
@MainActor
final class FreeCreditsService: ObservableObject {

    static let shared = FreeCreditsService()

    // MARK: - Constants
    static let monthlyLimit          = 3
    static let monthlyInterviewLimit = 5

    // MARK: - Persistence keys
    private enum Key {
        static let usedCount      = "freeCredits.usedCount"
        static let interviewCount = "freeCredits.interviewCount"
        static let resetMonth     = "freeCredits.resetMonth"  // "YYYY-MM"
    }

    // MARK: - Published
    @Published private(set) var remainingCredits:          Int = FreeCreditsService.monthlyLimit
    @Published private(set) var remainingInterviewSessions: Int = FreeCreditsService.monthlyInterviewLimit

    private let defaults: UserDefaults
    private let currentDate: () -> Date

    init(defaults: UserDefaults = .standard, currentDate: @escaping () -> Date = { Date() }) {
        self.defaults    = defaults
        self.currentDate = currentDate
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["MLExplorerForceCredits"],
           let n = Int(raw) {
            remainingCredits = n
            return
        }
        #endif
        refresh()
    }

    // MARK: - Deep insights

    func canView(isPro: Bool) -> Bool {
        isPro || remainingCredits > 0
    }

    func consume() {
        guard remainingCredits > 0 else { return }
        let used = defaults.integer(forKey: Key.usedCount) + 1
        defaults.set(used, forKey: Key.usedCount)
        remainingCredits = max(0, FreeCreditsService.monthlyLimit - used)
    }

    // MARK: - Mock interview sessions

    func canStartInterview(isPro: Bool) -> Bool {
        isPro || remainingInterviewSessions > 0
    }

    func consumeInterview() {
        guard remainingInterviewSessions > 0 else { return }
        let used = defaults.integer(forKey: Key.interviewCount) + 1
        defaults.set(used, forKey: Key.interviewCount)
        remainingInterviewSessions = max(0, FreeCreditsService.monthlyInterviewLimit - used)
    }

    // MARK: - Monthly reset

    func refreshIfNeeded() { refresh() }

    // MARK: - Private

    private func refresh() {
        let thisMonth   = monthString(from: currentDate())
        let storedMonth = defaults.string(forKey: Key.resetMonth) ?? ""

        if storedMonth != thisMonth {
            defaults.set(0,         forKey: Key.usedCount)
            defaults.set(0,         forKey: Key.interviewCount)
            defaults.set(thisMonth, forKey: Key.resetMonth)
        }

        let usedInsights  = defaults.integer(forKey: Key.usedCount)
        let usedInterviews = defaults.integer(forKey: Key.interviewCount)
        remainingCredits           = max(0, FreeCreditsService.monthlyLimit          - usedInsights)
        remainingInterviewSessions = max(0, FreeCreditsService.monthlyInterviewLimit - usedInterviews)
    }

    private func monthString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return fmt.string(from: date)
    }
}
