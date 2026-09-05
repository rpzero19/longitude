import XCTest

/// Drives the import screen the way a person does.
///
/// This exists because the photo path broke twice in ways no logic test could
/// see: the failure was in how the picker was presented, not in what the app
/// did with the image. Both escapes reached a real device.
final class ImportFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "YES"]
        app.launch()
        return app
    }

    private func openImport(_ app: XCUIApplication) {
        // Either the empty state's button or the toolbar menu, depending on
        // whether this simulator already has results saved.
        if app.buttons["Add a report"].waitForExistence(timeout: 5) {
            app.buttons["Add a report"].tap()
        } else {
            app.buttons["ellipsis.circle"].tap()
            app.buttons["Add a report"].tap()
        }
    }

    /// The bug that shipped twice: picking an image tore down the whole import
    /// sheet, so nothing was ever saved. The assertion that matters is that the
    /// import screen is still standing afterwards.
    func testPickingAPhotoKeepsTheImportScreenAlive() {
        let app = launch()
        openImport(app)

        XCTAssertTrue(app.buttons["Photograph or pick an image"].waitForExistence(timeout: 5))
        app.buttons["Photograph or pick an image"].tap()

        // The picker is presented into this process on current iOS, so it is
        // reachable through `app` rather than a separate application.
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 20),
                      "The photo picker never appeared")

        let grid = app.collectionViews.firstMatch
        XCTAssertTrue(grid.waitForExistence(timeout: 10))
        let photo = grid.images.firstMatch
        guard photo.waitForExistence(timeout: 10) else {
            XCTFail("No photo in the simulator library — add one with simctl addmedia")
            return
        }
        // The grid's cells report themselves as not hittable, so tap the frame
        // directly rather than relying on hit-testing.
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Reading, then either the review screen or an explained failure. What
        // must never happen is the import screen vanishing silently.
        let review = app.navigationBars["Check the results"]
        let stillChoosing = app.navigationBars["Add a report"]
        // The failure path is an inline banner now, not an alert.
        let explained = app.images["exclamationmark.triangle.fill"]

        let deadline = Date().addingTimeInterval(40)
        while Date() < deadline {
            if review.exists || explained.exists { break }
            usleep(300_000)
        }

        XCTAssertTrue(review.exists || explained.exists || stillChoosing.exists,
                      "The import screen disappeared after picking a photo")
        XCTAssertTrue(review.exists,
                      "Expected the review screen after reading a legible report")
        XCTAssertTrue(app.staticTexts["Haemoglobin"].waitForExistence(timeout: 5),
                      "The results read from the photo should be listed")
    }

    /// The path that needs no file at all, and the floor under every lab the
    /// parser has never seen.
    func testEnteringAResultByHand() {
        let app = launch()
        openImport(app)

        XCTAssertTrue(app.buttons["Enter results by hand"].waitForExistence(timeout: 5))
        app.buttons["Enter results by hand"].tap()

        let name = app.textFields["Test name, as the report prints it"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Haemoglobin")

        app.textFields["0.0"].tap()
        app.textFields["0.0"].typeText("14.2")

        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["Haemoglobin"].waitForExistence(timeout: 5),
                      "The hand-entered result should appear on the review screen")
        XCTAssertTrue(app.buttons["Save"].isEnabled)
    }
}
