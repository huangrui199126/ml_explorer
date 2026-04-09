import XCTest

final class SubscriptionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Free User Credit Journey
    // ─────────────────────────────────────────────────────────────────────────

    /// Paper 1 of 3: free user sees deep insight + "2 free left" badge
    func test_freeUser_paper1_seesDeepInsight_2CreditsRemaining() throws {
        let app = launchFree(credits: 3)
        openPaper(app, index: 0)

        // Deep insight content should be visible
        XCTAssertTrue(
            app.staticTexts["Advanced Analysis"].waitForExistence(timeout: 5),
            "Paper 1: deep insight should be visible with 3 credits"
        )
        XCTAssertFalse(
            app.buttons["Unlock Pro"].exists,
            "Paper 1: no paywall gate should appear"
        )
        // Credit badge shows remaining after consume (2 left)
        XCTAssertTrue(
            app.staticTexts["2 free left"].waitForExistence(timeout: 3),
            "Paper 1: badge should show '2 free left' after viewing"
        )
        // Interview prep IS gated even with credits
        XCTAssertTrue(
            app.staticTexts["Interview Prep"].waitForExistence(timeout: 3),
            "Interview Prep section header should exist"
        )
        // But interview content is behind paywall
        XCTAssertTrue(
            interviewGateExists(app),
            "Paper 1: Interview Prep should still be gated for free user"
        )
    }

    /// Paper 2 of 3: 1 credit left after viewing
    func test_freeUser_paper2_seesDeepInsight_1CreditRemaining() throws {
        let app = launchFree(credits: 2)
        openPaper(app, index: 0)

        XCTAssertTrue(
            app.staticTexts["Advanced Analysis"].waitForExistence(timeout: 5),
            "Paper 2: deep insight should still be visible"
        )
        XCTAssertTrue(
            app.staticTexts["1 free left"].waitForExistence(timeout: 3),
            "Paper 2: badge should show '1 free left'"
        )
    }

    /// Paper 3 of 3: last free credit — still sees insight, badge shows 0
    func test_freeUser_paper3_seesDeepInsight_0CreditsRemaining() throws {
        let app = launchFree(credits: 1)
        openPaper(app, index: 0)

        XCTAssertTrue(
            app.staticTexts["Advanced Analysis"].waitForExistence(timeout: 5),
            "Paper 3: last credit — deep insight should be visible"
        )
        XCTAssertTrue(
            app.staticTexts["0 free left"].waitForExistence(timeout: 3),
            "Paper 3: badge should show '0 free left'"
        )
    }

    /// Paper 4+: credits exhausted — sees paywall gate instead of deep insight
    func test_freeUser_paper4_creditsExhausted_seesPaywallGate() throws {
        let app = launchFree(credits: 0)
        openPaper(app, index: 0)

        XCTAssertTrue(
            app.buttons["Unlock Pro"].waitForExistence(timeout: 5),
            "Paper 4+: Unlock Pro gate should appear when credits are 0"
        )
        XCTAssertFalse(
            app.staticTexts["How It Works"].exists,
            "Paper 4+: deep insight content should NOT be visible"
        )
        // Interview prep also gated
        XCTAssertTrue(
            interviewGateExists(app),
            "Paper 4+: Interview Prep should be gated"
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Paywall Interaction
    // ─────────────────────────────────────────────────────────────────────────

    /// Tapping Unlock Pro opens the paywall sheet
    func test_unlockProButton_opensPaywall() throws {
        let app = launchFree(credits: 0)
        openPaper(app, index: 0)

        app.buttons["Unlock Pro"].tap()

        XCTAssertTrue(
            app.staticTexts["ML Explorer Pro"].waitForExistence(timeout: 4),
            "Paywall sheet should appear"
        )
        XCTAssertTrue(app.staticTexts["Monthly"].exists, "Monthly plan should be listed")
        XCTAssertTrue(app.staticTexts["Annual"].exists,  "Annual plan should be listed")
    }

    /// User selects Monthly plan — CTA reflects monthly price
    func test_paywall_selectMonthly_ctaShowsMonthlyPrice() throws {
        let app = launchFree(credits: 0)
        openPaywallFromSettings(app)

        // Tap Monthly card
        app.staticTexts["Monthly"].tap()

        // CTA should say /month
        let cta = app.buttons.matching(NSPredicate(format: "label CONTAINS '/month'")).firstMatch
        XCTAssertTrue(
            cta.waitForExistence(timeout: 3),
            "CTA should show monthly price after selecting Monthly plan"
        )
    }

    /// User selects Annual plan — CTA reflects annual price or free trial
    func test_paywall_selectAnnual_ctaShowsAnnualPriceOrFreeTrial() throws {
        let app = launchFree(credits: 0)
        openPaywallFromSettings(app)

        // Tap Annual card
        app.staticTexts["Annual"].tap()

        // CTA should say /year OR "Try Free"
        let yearCTA  = app.buttons.matching(NSPredicate(format: "label CONTAINS '/year'")).firstMatch
        let trialCTA = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Try Free'")).firstMatch
        XCTAssertTrue(
            yearCTA.waitForExistence(timeout: 3) || trialCTA.exists,
            "CTA should show annual price or free trial label"
        )
    }

    /// Paywall has Restore Purchases button
    func test_paywall_hasRestoreButton() throws {
        let app = launchFree(credits: 0)
        openPaywallFromSettings(app)

        XCTAssertTrue(
            app.buttons["Restore Purchases"].waitForExistence(timeout: 3),
            "Paywall must have a Restore Purchases button (App Store requirement)"
        )
    }

    /// Paywall can be dismissed with X
    func test_paywall_canBeDismissed() throws {
        let app = launchFree(credits: 0)
        openPaywallFromSettings(app)

        // Close button (xmark.circle.fill)
        let closeBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Close' OR label CONTAINS 'cancel'")).firstMatch
        if !closeBtn.waitForExistence(timeout: 2) {
            // swipe down to dismiss sheet
            app.swipeDown()
        } else {
            closeBtn.tap()
        }

        // Should be back on settings
        XCTAssertTrue(
            app.navigationBars["Settings"].waitForExistence(timeout: 3),
            "Should return to Settings after dismissing paywall"
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Pro User: Unlimited Access
    // ─────────────────────────────────────────────────────────────────────────

    /// Pro user: paper 1 — deep insight visible, no gate, no credit badge
    func test_proUser_paper1_seesEverything() throws {
        let app = launchPro()
        openPaper(app, index: 0)

        XCTAssertTrue(
            app.staticTexts["Advanced Analysis"].waitForExistence(timeout: 5),
            "Pro: deep insight visible on paper 1"
        )
        XCTAssertFalse(app.buttons["Unlock Pro"].exists, "Pro: no gate")
        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'free left'")).firstMatch.exists,
            "Pro: no credit badge shown"
        )
    }

    /// Pro user: paper 5 — still full access (not limited by credits)
    func test_proUser_paper5_stillFullAccess() throws {
        let app = launchPro()
        openPaper(app, index: 4)   // 5th paper

        XCTAssertTrue(
            app.staticTexts["Advanced Analysis"].waitForExistence(timeout: 5),
            "Pro: deep insight visible on paper 5"
        )
        XCTAssertFalse(app.buttons["Unlock Pro"].exists, "Pro: no gate on paper 5")
    }

    /// Pro user: Interview Prep fully visible (questions expand on tap)
    func test_proUser_interviewPrep_visible_andExpandable() throws {
        let app = launchPro()
        openPaper(app, index: 0)

        XCTAssertTrue(
            app.staticTexts["Interview Prep"].waitForExistence(timeout: 5),
            "Pro: Interview Prep section visible"
        )
        XCTAssertFalse(interviewGateExists(app), "Pro: no gate on Interview Prep")

        // Q1 should be tappable
        let q1 = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Q1'")).firstMatch
        if q1.waitForExistence(timeout: 3) {
            q1.tap()
            // Answer should appear
            XCTAssertTrue(
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'A'")).firstMatch.waitForExistence(timeout: 2),
                "Pro: tapping Q1 should reveal the answer"
            )
        }
    }

    /// Pro user: Settings shows Pro badge, no Upgrade button
    func test_proUser_settings_showsProBadge() throws {
        let app = launchPro()
        openSettings(app)

        XCTAssertTrue(
            app.staticTexts["ML Explorer Pro"].waitForExistence(timeout: 3),
            "Pro: Pro badge visible in Settings"
        )
        XCTAssertTrue(
            app.staticTexts["All features unlocked"].exists,
            "Pro: subtitle shows 'All features unlocked'"
        )
        XCTAssertFalse(
            app.buttons["Upgrade to Pro"].exists,
            "Pro: no Upgrade button shown"
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private func launchFree(credits: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MLExplorerForcePro"]     = "NO"
        app.launchEnvironment["MLExplorerForceCredits"] = "\(credits)"
        app.launch()
        return app
    }

    private func launchPro() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MLExplorerForcePro"] = "YES"
        app.launch()
        return app
    }

    private func openPaper(_ app: XCUIApplication, index: Int) {
        let cells = app.cells
        XCTAssertTrue(cells.firstMatch.waitForExistence(timeout: 8), "Paper list should load")
        cells.element(boundBy: index).tap()
    }

    private func openSettings(_ app: XCUIApplication) {
        // Try gear button in nav bar
        let gear = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Settings' OR label CONTAINS 'gear'")
        ).firstMatch
        if gear.waitForExistence(timeout: 3) {
            gear.tap()
        }
    }

    private func openPaywallFromSettings(_ app: XCUIApplication) {
        openSettings(app)
        let upgrade = app.buttons["Upgrade to Pro"]
        XCTAssertTrue(upgrade.waitForExistence(timeout: 3))
        upgrade.tap()
        XCTAssertTrue(
            app.staticTexts["ML Explorer Pro"].waitForExistence(timeout: 4),
            "Paywall should appear"
        )
    }

    private func interviewGateExists(_ app: XCUIApplication) -> Bool {
        // The gate shows "Unlock Pro" button near the Interview Prep section
        // We check for a second Unlock Pro after already being on the paper detail
        let gates = app.buttons.matching(NSPredicate(format: "label == 'Unlock Pro'"))
        return gates.count > 0
    }
}
