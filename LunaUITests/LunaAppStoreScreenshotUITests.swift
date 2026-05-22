import XCTest

final class LunaAppStoreScreenshotUITests: XCTestCase {
    private let screens: [(id: String, waitIdentifier: String?)] = [
        ("arPlacement", "screenshot.arPreview"),
        ("sceneExperience", nil),
        ("scaleControls", nil),
        ("objectDetail", nil),
        ("apod", nil),
        ("exploreLibrary", nil),
        ("home", nil),
        ("macMainWindow", nil)
    ]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCaptureAppStoreScreenshots() {
        for screen in screens {
            let app = XCUIApplication()
            app.launchArguments = [
                "-uiTesting",
                "-resetProfile",
                "-disableAnimations",
                "-screenshotMode",
                "-screenshotScreen",
                screen.id
            ]
            app.launch()

            XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8))
            if let waitIdentifier = screen.waitIdentifier {
                XCTAssertTrue(app.descendants(matching: .any)[waitIdentifier].waitForExistence(timeout: 8))
            } else {
                waitForIdleMoment()
            }

            capture(name: screen.id)
            app.terminate()
        }
    }

    private func capture(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Luna-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForIdleMoment() {
        let expectation = expectation(description: "screenshot settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }
}
