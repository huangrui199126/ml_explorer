import XCTest
@testable import MLExplorer

@MainActor
final class FreeCreditsServiceTests: XCTestCase {

    private let suiteName = "com.mlexplorer.test.credits"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Basic credit behaviour
    // ─────────────────────────────────────────────────────────────────────────

    func test_newUser_startsWithFullCredits() {
        let svc = makeSvc(month: "2026-03")
        XCTAssertEqual(svc.remainingCredits, 3)
    }

    func test_consume_decrementsOneAtATime() {
        let svc = makeSvc(month: "2026-03")
        svc.consume()
        XCTAssertEqual(svc.remainingCredits, 2)
        svc.consume()
        XCTAssertEqual(svc.remainingCredits, 1)
        svc.consume()
        XCTAssertEqual(svc.remainingCredits, 0)
    }

    func test_consume_neverGoesBelowZero() {
        let svc = makeSvc(month: "2026-03")
        svc.consume(); svc.consume(); svc.consume()
        svc.consume()   // 4th — should be ignored
        XCTAssertEqual(svc.remainingCredits, 0)
    }

    func test_canView_proUser_alwaysTrue_evenWithZeroCredits() {
        let svc = makeSvc(month: "2026-03")
        svc.consume(); svc.consume(); svc.consume()
        XCTAssertTrue(svc.canView(isPro: true))
    }

    func test_canView_freeUser_trueWhileCreditsRemain() {
        let svc = makeSvc(month: "2026-03")
        XCTAssertTrue(svc.canView(isPro: false))
        svc.consume()
        XCTAssertTrue(svc.canView(isPro: false))
    }

    func test_canView_freeUser_falseWhenExhausted() {
        let svc = makeSvc(month: "2026-03")
        svc.consume(); svc.consume(); svc.consume()
        XCTAssertFalse(svc.canView(isPro: false))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Monthly reset
    // ─────────────────────────────────────────────────────────────────────────

    /// Credits restore to 3 at the start of a new month.
    func test_newMonth_resetsCreditsToFull() {
        // Simulate: user exhausted credits in March
        let march = makeSvc(month: "2026-03")
        march.consume(); march.consume(); march.consume()
        XCTAssertEqual(march.remainingCredits, 0, "Sanity: credits exhausted in March")

        // April arrives — create service with April date using SAME UserDefaults
        let april = makeSvc(month: "2026-04")
        XCTAssertEqual(april.remainingCredits, 3, "Credits should reset to 3 in April")
    }

    /// If user consumed 1 in March, April still gets full 3 (not 2).
    func test_newMonth_alwaysResetsToFullLimit_notRemainder() {
        let march = makeSvc(month: "2026-03")
        march.consume()   // used 1 in March, 2 remaining
        XCTAssertEqual(march.remainingCredits, 2)

        let april = makeSvc(month: "2026-04")
        XCTAssertEqual(april.remainingCredits, 3,
                       "April always gets 3, not the March remainder")
    }

    /// Same month — credits do NOT reset mid-month.
    func test_sameMonth_doesNotReset() {
        let svc = makeSvc(month: "2026-03")
        svc.consume(); svc.consume()
        XCTAssertEqual(svc.remainingCredits, 1)

        // Re-init same month (simulates app relaunch in same month)
        let svc2 = makeSvc(month: "2026-03")
        XCTAssertEqual(svc2.remainingCredits, 1,
                       "Mid-month relaunch should NOT reset credits")
    }

    /// refreshIfNeeded in the same month does nothing.
    func test_refreshIfNeeded_sameMonth_noChange() {
        let svc = makeSvc(month: "2026-03")
        svc.consume(); svc.consume()
        XCTAssertEqual(svc.remainingCredits, 1)

        svc.refreshIfNeeded()   // still March
        XCTAssertEqual(svc.remainingCredits, 1,
                       "refreshIfNeeded in same month should leave credits unchanged")
    }

    /// Simulates app staying open across a month boundary:
    /// user exhausted credits in March, app stays open, month rolls to April,
    /// app comes to foreground → refreshIfNeeded resets credits.
    func test_refreshIfNeeded_acrossMonthBoundary_resetsCredits() {
        var fakeMonth = "2026-03"
        let svc = FreeCreditsService(
            defaults: defaults,
            currentDate: { self.date(from: fakeMonth) }
        )

        // Exhaust March credits
        svc.consume(); svc.consume(); svc.consume()
        XCTAssertEqual(svc.remainingCredits, 0, "March credits exhausted")

        // Month rolls over — simulate app coming to foreground in April
        fakeMonth = "2026-04"
        svc.refreshIfNeeded()

        XCTAssertEqual(svc.remainingCredits, 3,
                       "refreshIfNeeded should restore 3 credits after month rollover")
    }

    /// Full 12-month cycle: credits reset every single month.
    func test_fullYearCycle_creditsResetEachMonth() {
        let months = [
            "2026-01","2026-02","2026-03","2026-04",
            "2026-05","2026-06","2026-07","2026-08",
            "2026-09","2026-10","2026-11","2026-12"
        ]

        for month in months {
            // Reset UserDefaults for clean slate each month iteration
            defaults.removePersistentDomain(forName: suiteName)

            let svc = makeSvc(month: month)
            XCTAssertEqual(svc.remainingCredits, 3,
                           "Month \(month): should start with 3 credits")
            svc.consume(); svc.consume(); svc.consume()
            XCTAssertEqual(svc.remainingCredits, 0,
                           "Month \(month): credits should reach 0 after 3 consumes")
        }
    }

    /// Year boundary: December → January resets credits.
    func test_yearBoundary_decemberToJanuary_resetsCredits() {
        let dec = makeSvc(month: "2025-12")
        dec.consume(); dec.consume(); dec.consume()
        XCTAssertEqual(dec.remainingCredits, 0)

        let jan = makeSvc(month: "2026-01")
        XCTAssertEqual(jan.remainingCredits, 3,
                       "January of new year should reset credits to 3")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────────────────────

    /// Creates a service locked to a specific "YYYY-MM" month string.
    private func makeSvc(month: String) -> FreeCreditsService {
        FreeCreditsService(
            defaults: defaults,
            currentDate: { self.date(from: month) }
        )
    }

    /// Returns a Date whose year-month matches "YYYY-MM".
    private func date(from monthString: String) -> Date {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: "\(monthString)-01") ?? Date()
    }
}
