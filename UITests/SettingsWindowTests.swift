import XCTest

/// End-to-end: launches the app and drives the settings window.
/// `-uiTesting` gives the app a throwaway settings store, so these never touch the user's settings.
@MainActor
final class SettingsWindowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    // MARK: - Helpers

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func isOn(_ id: String) -> Bool {
        (element(id).value as? Int) == 1
    }

    /// Waits for a toggle to settle, since its value can lag the click.
    private func expect(_ id: String, on: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let settled = NSPredicate { _, _ in self.isOn(id) == on }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 3)
        XCTAssertEqual(result, .completed, "\(id) should be \(on ? "on" : "off")", file: file, line: line)
    }

    /// The menu bar icon isn't reachable from XCUITest (macOS hosts it outside the app),
    /// so with `-uiTesting` the app opens this window at launch.
    private func openSettings() {
        app.activate()
        XCTAssertTrue(element("main.tabs").waitForExistence(timeout: 5), "settings window")
    }

    /// Keeps a screenshot of the settings window in the test results.
    private func snapshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Picks a settings tab by its title.
    private func show(_ tab: String) {
        app.activate()
        element("main.tabs").radioButtons[tab].click()
    }

    // MARK: - Tests

    func testEveryTabShowsItsSettings() {
        openSettings()
        let tabs: [(String, String)] = [
            ("Orientation", "orientation.rotation"), ("Gestures", "main.target"),
            ("System", "permissions.checkAgain"), ("About", "support.githubSponsors"),
        ]
        for (tab, control) in tabs {
            show(tab)
            XCTAssertTrue(element(control).waitForExistence(timeout: 3), "\(tab) tab shows \(control)")
            snapshot("tab-\(tab.lowercased())")
        }
    }

    func testEnabledToggleFlips() {
        openSettings()
        expect("main.enabled", on: false) // -uiTesting starts with remapping off
        element("main.enabled").click()
        expect("main.enabled", on: true)
        element("main.enabled").click()
        expect("main.enabled", on: false)
    }

    func testResetAxesClearsSwapAndInvert() {
        openSettings()
        show("Orientation")
        for id in ["orientation.swapXY", "orientation.invertX", "orientation.invertY"] {
            element(id).click()
            expect(id, on: true)
        }
        element("main.resetAxes").click()
        for id in ["orientation.swapXY", "orientation.invertX", "orientation.invertY"] {
            expect(id, on: false)
        }
    }

    func testScrollRemapGatesSwipeNavigation() {
        openSettings()
        show("Gestures")
        expect("apply.scroll", on: true)
        XCTAssertTrue(element("apply.swipeNavigation").isEnabled)
        element("apply.scroll").click()
        XCTAssertFalse(element("apply.swipeNavigation").isEnabled)
        element("apply.scroll").click()
        XCTAssertTrue(element("apply.swipeNavigation").isEnabled)
    }

    func testHapticsNeedAnEdgeSlider() {
        openSettings()
        show("Gestures")
        XCTAssertFalse(element("edgeSliders.haptics").isEnabled, "off while no trackpad has edge sliders")
        element("edgeSliders.builtIn").click()
        XCTAssertTrue(element("edgeSliders.haptics").isEnabled)
    }

    func testSupportListsEveryOption() {
        openSettings()
        show("About")
        for id in ["githubSponsors", "buyMeACoffee", "koFi", "paypal", "saweria", "github"] {
            XCTAssertTrue(element("support.\(id)").exists, id)
        }
    }

    func testWhatsNewSheetOpensAndCloses() {
        openSettings()
        show("About")
        element("about.whatsNew").click()
        let close = element("whatsNew.close")
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        snapshot("whats-new")
        close.click()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
    }
}
