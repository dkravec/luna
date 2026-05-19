import XCTest

final class LunaTourUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testTourNextBackAndDoneFlow() {
        launchTourPending(resetProfile: true)

        assertTour(title: "Start From Home", progress: "1 of 10")
        assertSpotlightAligned(with: "tourTarget.home.overview")

        tapNext()
        assertTour(title: "Open Explore", progress: "2 of 10")

        tapNext()
        assertTour(title: "Browse Collections", progress: "3 of 10")
        assertSpotlightAligned(with: "tourTarget.explore.category")

        tapBack()
        assertTour(title: "Open Explore", progress: "2 of 10")

        tapBack()
        assertTour(title: "Start From Home", progress: "1 of 10")

        tapNext()
        assertTour(title: "Open Explore", progress: "2 of 10")

        tapNext()
        assertTour(title: "Browse Collections", progress: "3 of 10")

        tapNext()
        assertTour(title: "Open A Body", progress: "4 of 10")

        tapNext()
        assertTour(title: "View It In Space", progress: "5 of 10")

        tapNext()
        assertTour(title: "Move Through The Scene", progress: "6 of 10")
        assertSpotlightAligned(with: "tourTarget.experience.scene", tolerance: 24)

        tapNext()
        assertTour(title: "Switch Modes", progress: "7 of 10")

        tapNext()
        assertTour(title: "Tune The Scene", progress: "8 of 10")

        tapNext()
        assertTour(title: "Play Or Place", progress: "9 of 10")

        tapNext()
        assertTour(title: "You Are Ready", progress: "10 of 10")

        tapNext()
        XCTAssertTrue(waitForTourToDisappear())

        app.terminate()
        launchApp(arguments: ["-uiTesting", "-disableAnimations"])
        XCTAssertTrue(waitForTourToDisappear())
    }

    func testEndTourRemovesOverlay() {
        launchTourPending(resetProfile: true)
        XCTAssertTrue(app.otherElements["tour.overlay"].waitForExistence(timeout: 3))

        tapElement(app.descendants(matching: .any)["tour.end"])

        XCTAssertTrue(waitForTourToDisappear())
    }

    func testReplayTourFromSettingsStartsAtHome() {
        launchApp(arguments: ["-uiTesting", "-resetProfile", "-completeOnboarding", "-disableAnimations"])
        XCTAssertTrue(waitForTourToDisappear())

        app.buttons["Settings"].tap()
        let replay = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Replay App Tour")).firstMatch
        XCTAssertTrue(replay.waitForExistence(timeout: 3))
        replay.tap()

        assertTour(title: "Start From Home", progress: "1 of 10")
        assertSpotlightAligned(with: "tourTarget.home.overview")
    }

    private func launchTourPending(resetProfile: Bool) {
        var arguments = ["-uiTesting", "-completeOnboarding", "-firstRunTourPending", "-disableAnimations"]
        if resetProfile {
            arguments.insert("-resetProfile", at: 1)
        }
        launchApp(arguments: arguments)
    }

    private func launchApp(arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
    }

    private func tapNext() {
        let button = app.descendants(matching: .any)["tour.next"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        tapElement(button)
    }

    private func tapBack() {
        let button = app.descendants(matching: .any)["tour.back"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        tapElement(button)
    }

    private func assertTour(title: String, progress: String) {
        XCTAssertTrue(app.otherElements["tour.overlay"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts[progress].waitForExistence(timeout: 3))
    }

    private func assertSpotlightAligned(with targetIdentifier: String, tolerance: CGFloat = 18) {
        let target = app.descendants(matching: .any)[targetIdentifier]
        let spotlight = app.descendants(matching: .any)["tour.spotlight"]

        XCTAssertTrue(target.waitForExistence(timeout: 3), "Missing target \(targetIdentifier)")
        XCTAssertTrue(spotlight.waitForExistence(timeout: 3), "Missing tour spotlight")

        XCTAssertLessThanOrEqual(spotlight.frame.minX, target.frame.minX + tolerance)
        XCTAssertLessThanOrEqual(spotlight.frame.minY, target.frame.minY + tolerance)
        XCTAssertGreaterThanOrEqual(spotlight.frame.maxX, target.frame.maxX - tolerance)
        if target.frame.maxY <= app.frame.maxY - 90 {
            XCTAssertGreaterThanOrEqual(spotlight.frame.maxY, target.frame.maxY - tolerance)
        }
    }

    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForTourToDisappear(timeout: TimeInterval = 3) -> Bool {
        waitForElementToDisappear(app.descendants(matching: .any)["tour.end"], timeout: timeout)
            && waitForElementToDisappear(app.descendants(matching: .any)["tour.next"], timeout: timeout)
    }

    private func tapElement(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
