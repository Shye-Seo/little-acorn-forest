import XCTest
import AcornForestCore

final class GatheringTests: XCTestCase {
    func testSessionGeneratesItemsInsideTheTimeline() {
        let session = GatheringSession(location: .berryPatch, seed: 7)
        XCTAssertFalse(session.items.isEmpty)
        for item in session.items {
            XCTAssertTrue((0..<GatheringSession.laneCount).contains(item.lane))
            XCTAssertLessThanOrEqual(item.catchTime, session.duration)
            XCTAssertGreaterThan(item.fallDuration, 0)
            XCTAssertTrue(session.location.ingredientPool.contains(item.ingredient))
        }
    }

    func testSeedMakesSessionsReproducible() {
        let first = GatheringSession(location: .fireflyPond, seed: 99)
        let second = GatheringSession(location: .fireflyPond, seed: 99)
        let third = GatheringSession(location: .fireflyPond, seed: 100)
        XCTAssertEqual(first.items.map(\.catchTime), second.items.map(\.catchTime))
        XCTAssertEqual(first.items.map(\.ingredient), second.items.map(\.ingredient))
        XCTAssertNotEqual(first.items.map(\.catchTime), third.items.map(\.catchTime))
    }

    func testTappingAtCatchTimeCatchesEveryItem() {
        var session = GatheringSession(location: .berryPatch, seed: 21)
        let items = session.items.sorted { $0.catchTime < $1.catchTime }
        var clock = 0.0
        for item in items {
            let delta = item.catchTime - clock
            if delta > 0 {
                session.tick(delta)
                clock = item.catchTime
            }
            _ = session.tap(lane: item.lane)
        }
        XCTAssertEqual(session.caughtCount, items.count)
        XCTAssertEqual(session.missedCount, 0)
        XCTAssertGreaterThan(session.score, 0)
        XCTAssertEqual(session.bestStreak, items.count)
    }

    func testTapOutsideTheWindowDoesNothing() {
        var session = GatheringSession(location: .berryPatch, seed: 5)
        XCTAssertEqual(session.tap(lane: 0), .nothing)
        XCTAssertEqual(session.tap(lane: -1), .nothing)
        XCTAssertEqual(session.tap(lane: 99), .nothing)
        XCTAssertEqual(session.score, 0)
        XCTAssertEqual(session.caughtCount, 0)
    }

    func testMissedItemsResetStreakAndLowerScore() {
        var session = GatheringSession(location: .owlLibrary, seed: 33)
        session.tick(session.duration * 0.6)
        XCTAssertGreaterThan(session.missedCount, 0)
        XCTAssertEqual(session.streak, 0)
        XCTAssertEqual(session.score, 0)
    }

    func testSessionFinishesAtDuration() {
        var session = GatheringSession(location: .cabinKitchen, seed: 3)
        session.tick(1000)
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.progress, 1, accuracy: 0.0001)
        XCTAssertEqual(session.remaining, 0, accuracy: 0.0001)
        let before = session.score
        session.tick(1)
        XCTAssertEqual(session.score, before, "끝난 뒤에는 점수가 변하지 않는다")
    }

    func testHarvestAddsUpToCaughtItems() {
        var session = GatheringSession(location: .fireflyPond, seed: 11)
        let items = session.items.sorted { $0.catchTime < $1.catchTime }
        var clock = 0.0
        for item in items.prefix(4) {
            let delta = item.catchTime - clock
            if delta > 0 {
                session.tick(delta)
                clock = item.catchTime
            }
            _ = session.tap(lane: item.lane)
        }
        let total = session.harvest.reduce(0) { $0 + $1.count }
        XCTAssertEqual(total, session.caughtCount)
    }

    func testComboMultiplierGrowsAndCaps() {
        var session = GatheringSession(location: .berryPatch, seed: 2)
        XCTAssertEqual(session.comboMultiplier, 1.0, accuracy: 0.0001)
        session.tick(0)
        XCTAssertEqual(session.streak, 0)
    }

    func testBonusHarvestOnLongStreak() {
        var session = GatheringSession(location: .berryPatch, seed: 21)
        let items = session.items.sorted { $0.catchTime < $1.catchTime }
        var clock = 0.0
        for item in items {
            let delta = item.catchTime - clock
            if delta > 0 {
                session.tick(delta)
                clock = item.catchTime
            }
            _ = session.tap(lane: item.lane)
        }
        XCTAssertGreaterThanOrEqual(session.bestStreak, 6)
        XCTAssertTrue(session.bonusHarvest.contains { $0.ingredient == .moonflakeSpice })
        let summary = session.summary()
        XCTAssertTrue(summary.accuracy > 0.99)
    }

    func testEngineStoresHarvestAndStats() {
        let engine = TestSupport.engine(state: TestSupport.stateWithPrologueDone())
        XCTAssertTrue(engine.startGathering(at: .berryPatch, seed: 21))
        TestSupport.catchEverything(engine)
        XCTAssertNil(engine.gathering)
        XCTAssertGreaterThan(engine.state.stats.totalCaught, 0)
        XCTAssertEqual(engine.state.stats.gatherRounds, 1)
        XCTAssertGreaterThan(engine.state.totalIngredients, 0)
    }

    func testLockedLocationCannotBeGathered() {
        let engine = TestSupport.engine()
        XCTAssertFalse(engine.startGathering(at: .owlLibrary, seed: 1))
        XCTAssertFalse(engine.startGathering(at: .festivalGlade, seed: 1))
    }
}
