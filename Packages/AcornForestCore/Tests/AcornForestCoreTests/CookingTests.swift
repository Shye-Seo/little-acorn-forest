import XCTest
import AcornForestCore

final class CookingTests: XCTestCase {
    func testHoldingHeatInBandGivesPerfectQuality() {
        var session = CookingSession(ingredients: [.acorn, .raspberry])
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
        var session = CookingSession(ingredients: [.acorn, .raspberry])
        for _ in 0..<80 {
            session.tick(0.1)
        }
        XCTAssertTrue(session.isFinished)
        XCTAssertTrue(session.burned)
        XCTAssertEqual(session.quality, .burnt)
    }

    func testSessionEndsExactlyAtDuration() {
        var session = CookingSession(ingredients: [.moonHerb, .honeyMushroom])
        session.tick(100)
        XCTAssertEqual(session.elapsed, CookingSession.duration, accuracy: 0.0001)
        XCTAssertEqual(session.progress, 1, accuracy: 0.0001)
        XCTAssertEqual(session.remaining, 0, accuracy: 0.0001)
    }

    func testStirCoolsButNeverBelowFloor() {
        var session = CookingSession(ingredients: [.acorn])
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
        var session = CookingSession(ingredients: [.raspberry])
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
            ItemStack(.acorn, 1),
            ItemStack(.raspberry, 1)
        ])
        let engine = GameEngine(saveStore: InMemorySaveStore(), state: state)
        XCTAssertTrue(engine.startCooking(ingredients: [.acorn, .raspberry]))
        TestSupport.stirToPerfect(engine)
        let outcome = engine.finishCooking()
        XCTAssertEqual(outcome?.recipe?.id, "acorn-pie")
        XCTAssertEqual(outcome?.isNewRecipe, true)
        XCTAssertEqual(engine.state.count(of: .acorn), 0)
        XCTAssertEqual(engine.state.servings(of: "acorn-pie"), 1)
        XCTAssertTrue(engine.state.hasDiary("recipe.acorn-pie"))
        XCTAssertEqual(engine.state.stats.cooks, 1)
    }

    func testCookingWithoutIngredientsIsRefused() {
        let engine = TestSupport.engine(state: TestSupport.stockedState([]))
        XCTAssertFalse(engine.startCooking(ingredients: [.acorn, .raspberry]))
    }

    func testTooManyIngredientsRefused() {
        let engine = TestSupport.engine(state: TestSupport.stockedState([
            ItemStack(.acorn, 5),
            ItemStack(.raspberry, 5),
            ItemStack(.moonHerb, 5),
            ItemStack(.honeyMushroom, 5)
        ]))
        XCTAssertFalse(engine.startCooking(ingredients: [.acorn, .raspberry, .moonHerb, .honeyMushroom]))
    }

    func testUnknownCombinationStillConsumesIngredients() {
        let engine = TestSupport.engine(state: TestSupport.stockedState([
            ItemStack(.acorn, 2)
        ]))
        XCTAssertTrue(engine.startCooking(ingredients: [.acorn, .acorn]))
        let outcome = engine.finishCooking()
        XCTAssertNil(outcome?.recipe)
        XCTAssertEqual(engine.state.count(of: .acorn), 0)
        XCTAssertTrue(outcome?.message.contains("레시피") ?? false)
    }
}
