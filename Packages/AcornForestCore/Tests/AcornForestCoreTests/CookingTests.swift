import XCTest
import AcornForestCore

final class CookingTests: XCTestCase {
    func testHoldingHeatInBandGivesPerfectQuality() {
        var session = CookingSession(ingredients: [.dewberry, .fireflyNectar])
        var guardCount = 0
        while !session.isFinished && guardCount < 200 {
            guardCount += 1
            session.tick(0.1)
            if session.heat > 0.62 {
                session.stir()
            }
        }
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.quality, .perfect)
        XCTAssertGreaterThan(session.stirs, 0)
    }

    func testNotStirringBurnsThePot() {
        var session = CookingSession(ingredients: [.dewberry, .fireflyNectar])
        for _ in 0..<80 {
            session.tick(0.1)
        }
        XCTAssertTrue(session.isFinished)
        XCTAssertTrue(session.burned)
        XCTAssertEqual(session.quality, .burnt)
    }

    func testSessionEndsExactlyAtDuration() {
        var session = CookingSession(ingredients: [.starMossShroom, .moonflakeSpice])
        session.tick(100)
        XCTAssertEqual(session.elapsed, CookingSession.duration, accuracy: 0.0001)
        XCTAssertEqual(session.progress, 1, accuracy: 0.0001)
        XCTAssertEqual(session.remaining, 0, accuracy: 0.0001)
    }

    func testStirCoolsButNeverBelowFloor() {
        var session = CookingSession(ingredients: [.dewberry])
        for _ in 0..<10 {
            session.stir()
        }
        XCTAssertEqual(session.heat, 0.05, accuracy: 0.0001)
        XCTAssertEqual(session.stirs, 10)
    }

    func testQualityGiftBonus() {
        XCTAssertEqual(CookingQuality.perfect.giftBonus, 3)
        XCTAssertEqual(CookingQuality.good.giftBonus, 0)
        XCTAssertEqual(CookingQuality.burnt.giftBonus, 0)
        XCTAssertTrue(CookingQuality.good < CookingQuality.perfect)
    }

    func testHeatPhaseReflectsBand() {
        var session = CookingSession(ingredients: [.dewberry])
        XCTAssertEqual(session.phase, .low)
        var steps = 0
        while session.heat < 0.45 && steps < 50 {
            steps += 1
            session.tick(0.1)
        }
        XCTAssertEqual(session.phase, .ideal)
    }

    func testCookingConsumesIngredientsAndRecordsRecipe() {
        let state = TestSupport.stockedState([
            ItemStack(.dewberry, 2)
        ])
        let engine = GameEngine(saveStore: InMemorySaveStore(), state: state)
        engine.moonClock = MoonClock(overridePhase: .waning)
        XCTAssertTrue(engine.startCooking(ingredients: [.dewberry, .dewberry]))
        TestSupport.stirToPerfect(engine)
        let outcome = engine.finishCooking()
        XCTAssertEqual(outcome?.recipe?.id, "dawn-dew-jam")
        XCTAssertEqual(outcome?.isNewRecipe, true)
        XCTAssertEqual(engine.state.count(of: .dewberry), 0)
        XCTAssertEqual(engine.state.servings(of: "dawn-dew-jam"), 1)
        XCTAssertEqual(engine.state.count(of: .moonflakeSpice), 1, "그믐달 축복으로 향신료 한 줌")
        XCTAssertTrue(engine.state.hasDiary("recipe.dawn-dew-jam"))
        XCTAssertEqual(engine.state.stats.cooks, 1)
    }

    func testCookingWithoutIngredientsIsRefused() {
        let engine = TestSupport.engine(state: TestSupport.stockedState([]))
        XCTAssertFalse(engine.startCooking(ingredients: [.dewberry, .fireflyNectar]))
    }

    func testTooManyIngredientsRefused() {
        let engine = TestSupport.engine(state: TestSupport.stockedState([
            ItemStack(.dewberry, 5),
            ItemStack(.fireflyNectar, 5),
            ItemStack(.starMossShroom, 5),
            ItemStack(.moonflakeSpice, 5)
        ]))
        XCTAssertFalse(engine.startCooking(ingredients: [.dewberry, .fireflyNectar, .starMossShroom, .moonflakeSpice]))
    }

    func testUnknownCombinationStillConsumesIngredients() {
        let engine = TestSupport.engine(state: TestSupport.stockedState([
            ItemStack(.fireflyNectar, 2)
        ]))
        XCTAssertTrue(engine.startCooking(ingredients: [.fireflyNectar, .fireflyNectar]))
        let outcome = engine.finishCooking()
        XCTAssertNil(outcome?.recipe)
        XCTAssertEqual(engine.state.count(of: .fireflyNectar), 0)
        XCTAssertTrue(outcome?.message.contains("레시피") ?? false)
    }
}
