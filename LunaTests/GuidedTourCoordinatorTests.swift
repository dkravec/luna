import XCTest
@testable import Luna

final class GuidedTourCoordinatorTests: XCTestCase {
    func testForwardAndBackSequenceRoutesThroughExpectedSteps() {
        let coordinator = GuidedTourCoordinator()
        var routes: [GuidedTourRoute] = []
        coordinator.defaultCollectionIDProvider = { "solarSystem" }
        coordinator.defaultBodyIDProvider = { "earth" }
        coordinator.routeHandler = { routes.append($0) }

        coordinator.start()
        XCTAssertEqual(coordinator.currentStep, .homeWelcome)
        XCTAssertEqual(routes.last, .home)

        XCTAssertTrue(coordinator.next())
        waitForTransitionUnlock()
        XCTAssertEqual(coordinator.currentStep, .homeExplore)

        XCTAssertTrue(coordinator.next())
        waitForTransitionUnlock()
        XCTAssertEqual(coordinator.currentStep, .exploreCategories)
        XCTAssertEqual(routes.last, .explore)

        XCTAssertTrue(coordinator.next())
        waitForTransitionUnlock()
        XCTAssertEqual(coordinator.currentStep, .exploreBody)
        XCTAssertEqual(coordinator.pendingCollectionID, "solarSystem")
        XCTAssertNil(coordinator.pendingBodyID)
        XCTAssertEqual(routes.last, .explore)

        XCTAssertTrue(coordinator.next())
        waitForTransitionUnlock()
        XCTAssertEqual(coordinator.currentStep, .bodyDetailExperience)
        XCTAssertEqual(coordinator.pendingCollectionID, "solarSystem")
        XCTAssertEqual(coordinator.pendingBodyID, "earth")
        XCTAssertEqual(routes.last, .bodyDetail("earth"))

        XCTAssertTrue(coordinator.back())
        waitForTransitionUnlock()
        XCTAssertEqual(coordinator.currentStep, .exploreBody)
        XCTAssertEqual(coordinator.pendingCollectionID, "solarSystem")
        XCTAssertNil(coordinator.pendingBodyID)
        XCTAssertEqual(routes.last, .explore)
    }

    func testTargetTapOnlyAdvancesMatchingActionableStep() {
        let coordinator = GuidedTourCoordinator()
        coordinator.start()

        XCTAssertFalse(coordinator.targetTapped(.homeOverview))
        XCTAssertEqual(coordinator.currentStep, .homeWelcome)

        XCTAssertTrue(coordinator.next())
        waitForTransitionUnlock()
        XCTAssertEqual(coordinator.currentStep, .homeExplore)

        XCTAssertFalse(coordinator.targetTapped(.exploreCategory))
        XCTAssertEqual(coordinator.currentStep, .homeExplore)

        XCTAssertTrue(coordinator.targetTapped(.homeExploreAction))
        waitForTransitionUnlock()
        XCTAssertEqual(coordinator.currentStep, .exploreCategories)
    }

    func testSkipAndFinishPersistCompletionCallback() {
        let coordinator = GuidedTourCoordinator()
        var completionCount = 0
        coordinator.completionHandler = { completionCount += 1 }

        coordinator.start()
        coordinator.skip()

        XCTAssertNil(coordinator.currentStep)
        XCTAssertNil(coordinator.pendingCollectionID)
        XCTAssertNil(coordinator.pendingBodyID)
        XCTAssertEqual(completionCount, 1)
    }

    func testRapidNextDoesNotAdvanceTwiceInSameRunLoop() {
        let coordinator = GuidedTourCoordinator()
        coordinator.start()

        XCTAssertTrue(coordinator.next())
        XCTAssertFalse(coordinator.next())
        XCTAssertEqual(coordinator.currentStep, .homeExplore)

        waitForTransitionUnlock()
        XCTAssertTrue(coordinator.next())
        XCTAssertEqual(coordinator.currentStep, .exploreCategories)
    }

    private func waitForTransitionUnlock() {
        let expectation = expectation(description: "Transition lock released")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}
