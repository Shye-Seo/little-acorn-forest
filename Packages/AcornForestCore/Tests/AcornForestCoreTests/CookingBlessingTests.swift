import XCTest
import AcornForestCore

final class CookingBlessingTests: XCTestCase {
    private func stockedEngine(_ moon: MoonPhase) -> GameEngine {
        let state = TestSupport.stockedState([
            ItemStack(.dewberry, 2),
            ItemStack(.fireflyNectar, 2),
            ItemStack(.moonflakeSpice, 0)
        ])
        return TestSupport.engine(state: state, moon: moon)
    }

    private func cookPerfect(_ engine: GameEngine) -> CookingOutcome? {
        guard engine.startCooking(ingredients: [.dewberry, .fireflyNectar]) else { return nil }
        TestSupport.stirToPerfect(engine)
        return engine.finishCooking()
    }

    func testCrescentBlessingLeavesDewberries() {
        let engine = stockedEngine(.crescent)
        let outcome = cookPerfect(engine)
        XCTAssertEqual(outcome?.recipe?.id, "firefly-sparkle-jam")
        XCTAssertEqual(engine.state.servings(of: "firefly-sparkle-jam"), 1)
        XCTAssertEqual(engine.state.count(of: .dewberry), 3, "초승달 이슬로 베리 두 알")
        XCTAssertEqual(outcome?.blessing?.tag, "blessing.crescent")
        XCTAssertTrue(outcome?.message.contains("초승달") ?? false)
    }

    func testFirstQuarterBlessingUpgradesQuality() {
        let engine = stockedEngine(.firstQuarter)
        XCTAssertTrue(engine.startCooking(ingredients: [.dewberry, .fireflyNectar]))
        for _ in 0..<80 {
            engine.tickCooking(0.1)
        }
        let outcome = engine.finishCooking()
        XCTAssertEqual(outcome?.quality, .good, "상현달의 결이 탄 잼을 보통으로 끌어올린다")
        XCTAssertEqual(engine.state.record(for: "firefly-sparkle-jam")?.bestQuality, .good)
        XCTAssertEqual(outcome?.blessing?.phase, .firstQuarter)
    }

    func testFullMoonBlessingAddsAServing() {
        let engine = stockedEngine(.fullMoon)
        let outcome = cookPerfect(engine)
        XCTAssertEqual(engine.state.servings(of: "firefly-sparkle-jam"), 2, "보름달에는 한 접시 더")
        XCTAssertEqual(outcome?.blessing?.bonusServings, 1)
        XCTAssertEqual(engine.state.record(for: "firefly-sparkle-jam")?.blessingTags.contains("blessing.fullMoon"), true)
    }

    func testWaningBlessingAddsMoonflakeSpice() {
        let engine = stockedEngine(.waning)
        _ = cookPerfect(engine)
        XCTAssertEqual(engine.state.count(of: .moonflakeSpice), 1)
        XCTAssertEqual(engine.lastMessage.contains("그믐달"), true)
    }

    func testBlessingUpgradeNeverSkipsADegree() {
        XCTAssertEqual(MoonBlessing.upgraded(.burnt), .good)
        XCTAssertEqual(MoonBlessing.upgraded(.good), .perfect)
        XCTAssertEqual(MoonBlessing.upgraded(.perfect), .perfect)
    }

    func testEveryPhaseHasItsOwnBlessing() {
        let tags = MoonPhase.allCases.map { MoonBlessing.forPhase($0).tag }
        XCTAssertEqual(Set(tags).count, 4)
        for phase in MoonPhase.allCases {
            let blessing = MoonBlessing.forPhase(phase)
            XCTAssertTrue(blessing.hasEffect, "\(phase.title) 축복에 효과가 없다")
            XCTAssertFalse(blessing.effectLine.isEmpty)
            XCTAssertEqual(blessing.phase, phase)
        }
    }

    func testBlessingLineIsEmptyWithoutEffect() {
        let plain = MoonBlessing(phase: .crescent, title: "없음", note: "없음", tag: "blessing.none")
        XCTAssertFalse(plain.hasEffect)
        let outcome = CookingOutcome(recipe: nil, attempted: [], quality: .good,
                                     gainedDiary: [], isNewRecipe: false, message: "m")
        XCTAssertEqual(outcome.blessingLine, "")
    }

    func testFullMoonBlessingSurvivesSaveAndRestore() throws {
        let engine = stockedEngine(.fullMoon)
        _ = cookPerfect(engine)
        let data = try SaveCodec.encode(SaveFile(state: engine.state))
        let restored = try SaveCodec.decode(data)
        XCTAssertEqual(restored.state.servings(of: "firefly-sparkle-jam"), 2)
        XCTAssertTrue(restored.state.record(for: "firefly-sparkle-jam")?.blessingTags.contains("blessing.fullMoon") ?? false)
    }
}
