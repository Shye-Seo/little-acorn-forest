import XCTest
import AcornForestCore

/// 「솥단지 불 조절 타이밍」 미니게임이 정한 규칙대로 판정하는지 확인한다.
final class SimmerMinigameTests: XCTestCase {
    // MARK: - 도우미

    /// 황금 구간 한가운데에서 맞는 손짓을 누르며 다섯 번의 부탁을 모두 처리한다.
    @discardableResult
    private func playGolden(_ game: inout SimmerMinigame) -> Int {
        var steps = 0
        while !game.isFinished && steps < 4000 {
            steps += 1
            guard let request = game.currentRequest else {
                game.tick(0.01)
                continue
            }
            if game.isAwaitingPress && request.isGolden(game.needle) {
                _ = game.press(request.action)
                continue
            }
            game.tick(0.01)
        }
        return game.score
    }

    /// 엔진이 들고 있는 세션을 직접 조작하며 황금빛으로 마무리한다.
    private func playGoldenOnEngine(_ engine: GameEngine) {
        var steps = 0
        while steps < 4000 {
            steps += 1
            guard let game = engine.simmer, !game.isFinished else { return }
            if let request = game.currentRequest, game.isAwaitingPress, request.isGolden(game.needle) {
                _ = engine.pressSimmer(request.action)
                continue
            }
            engine.tickSimmer(0.01)
        }
    }

    private func engineWithPot(finishHeat: Bool = true) -> GameEngine {
        var state = TestSupport.stockedState([
            ItemStack(.dewberry, 4),
            ItemStack(.starMossShroom, 4),
            ItemStack(.moonflakeSpice, 4)
        ])
        state.markCompleted(.prologue)
        let engine = TestSupport.engine(state: state)
        XCTAssertTrue(engine.startCooking(ingredients: [.dewberry, .starMossShroom]))
        if finishHeat {
            TestSupport.stirToPerfect(engine)
        }
        return engine
    }

    // MARK: - 부탁 만들기

    func testFiveRequestsAreDeterministicAndOrdered() {
        let first = SimmerMinigame(seed: 31)
        let second = SimmerMinigame(seed: 31)
        XCTAssertEqual(first.requests, second.requests)
        XCTAssertEqual(first.requests.count, SimmerMinigame.requestCount)
        for (index, request) in first.requests.enumerated() {
            XCTAssertEqual(request.id, index)
            XCTAssertTrue(0...1 ~= request.bandStart)
            XCTAssertTrue(0...1 ~= request.bandEnd)
            XCTAssertLessThan(request.bandStart, request.bandEnd)
            XCTAssertTrue(request.opensAt < request.closesAt)
            XCTAssertGreaterThanOrEqual(request.opensAt, Double(index) * 0.6)
        }
        XCTAssertNotEqual(SimmerMinigame(seed: 31).requests, SimmerMinigame(seed: 32).requests)
    }

    func testNeedleStaysInsideTheBar() {
        var game = SimmerMinigame(seed: 5)
        for _ in 0..<400 {
            game.tick(0.05)
            XCTAssertTrue(0...1 ~= game.needle, "바늘 \(game.needle)")
        }
        XCTAssertTrue(game.isFinished)
    }

    // MARK: - 판정

    func testGoldenPlayScoresTopGrade() {
        var game = SimmerMinigame(seed: 31)
        let score = playGolden(&game)
        XCTAssertEqual(game.goldens, SimmerMinigame.requestCount, game.outcome().summaryLine)
        XCTAssertEqual(game.hits, SimmerMinigame.requestCount)
        XCTAssertEqual(score, game.maxScore)
        XCTAssertEqual(game.grade, .golden)
        let outcome = game.outcome()
        XCTAssertEqual(outcome.rating, 1, accuracy: 0.0001)
        XCTAssertEqual(outcome.grade.qualityStep, 1)
        XCTAssertEqual(outcome.grade.extraServings, 1)
    }

    func testWrongActionIsAFumble() {
        var game = SimmerMinigame(seed: 31)
        // 첫 부탁이 열릴 때까지 기다린 뒤 반대 손짓을 누른다.
        while !game.isAwaitingPress && !game.isFinished { game.tick(0.01) }
        let request = game.currentRequest
        XCTAssertNotNil(request)
        let wrong: SimmerAction = request?.action == .lowerHeat ? .stirWooden : .lowerHeat
        let result = game.press(wrong)
        if case .fumble = result {
            XCTAssertEqual(game.fumbles, 1)
            XCTAssertEqual(game.score, 0)
        } else {
            XCTFail("반대 손짓은 헛손이어야 한다: \(result)")
        }
    }

    func testPressingOutsideTheBandIsAFumble() {
        var game = SimmerMinigame(seed: 31)
        while !game.isAwaitingPress && !game.isFinished { game.tick(0.01) }
        guard let request = game.currentRequest else { return XCTFail("부탁이 없다") }
        // 바늘이 구간 밖에 있을 때까지 기다린다.
        var steps = 0
        while request.contains(game.needle) && steps < 400 && !game.isFinished {
            steps += 1
            game.tick(0.01)
        }
        guard !request.contains(game.needle), game.isAwaitingPress else { return }
        let result = game.press(request.action)
        if case .fumble = result {
            XCTAssertEqual(game.hits, 0)
            XCTAssertEqual(game.fumbles, 1)
        } else {
            XCTFail("구간 밖에서 누르면 헛손이어야 한다: \(result)")
        }
    }

    func testIgnoringEveryRequestGivesTheLowestGrade() {
        var game = SimmerMinigame(seed: 8)
        game.tick(SimmerMinigame.duration + 1)
        XCTAssertTrue(game.isFinished)
        XCTAssertEqual(game.misses, SimmerMinigame.requestCount)
        XCTAssertEqual(game.hits, 0)
        XCTAssertEqual(game.score, 0)
        XCTAssertEqual(game.grade, .fumbled)
        XCTAssertEqual(game.outcome().rating, 0, accuracy: 0.0001)
    }

    func testPressBeforeTheRequestOpensIsIgnored() {
        var game = SimmerMinigame(seed: 12)
        XCTAssertFalse(game.isAwaitingPress)
        XCTAssertEqual(game.press(.lowerHeat), .ignored)
        XCTAssertEqual(game.fumbles, 0)
    }

    func testSteadyGradeSitsBelowGolden() {
        let outcome = SimmerOutcome(score: 60, maxScore: 150, grade: .steady,
                                    hits: 3, goldens: 0, misses: 2, fumbles: 0)
        XCTAssertEqual(outcome.rating, 0.4, accuracy: 0.0001)
        XCTAssertEqual(outcome.grade.qualityStep, 0)
        XCTAssertEqual(outcome.grade.extraServings, 0)
    }

    // MARK: - 엔진 연결

    func testSimmerNeedsAFinishedPot() {
        let engine = engineWithPot(finishHeat: false)
        XCTAssertFalse(engine.startSimmer(seed: 1))
        XCTAssertTrue(engine.lastMessage.contains("익지 않았"), engine.lastMessage)
        XCTAssertNil(engine.simmer)
    }

    func testGoldenSimmerUpgradesQualityAndAddsAServing() {
        let engine = engineWithPot()
        XCTAssertEqual(engine.cooking?.quality, .perfect, "불을 잘 잡으면 이미 완벽한 온기")
        XCTAssertTrue(engine.startSimmer(seed: 31))
        playGoldenOnEngine(engine)
        let outcome = engine.finishSimmer()
        XCTAssertEqual(outcome?.grade, .golden)

        let cooked = engine.finishCooking()
        XCTAssertEqual(cooked?.simmer?.grade, .golden)
        XCTAssertEqual(cooked?.recipe?.id, "starlight-mist-jam")
        XCTAssertEqual(engine.state.servings(of: "starlight-mist-jam"), 2,
                       "황금빛 마무리는 한 접시를 더 만든다")
    }

    func testSteadySimmerRescuesABurntPotOnlyOneStep() {
        let engine = engineWithPot(finishHeat: false)
        // 불을 잡지 않으면 솥이 탄다.
        engine.tickCooking(10)
        XCTAssertEqual(engine.cooking?.quality, .burnt)

        XCTAssertTrue(engine.startSimmer(seed: 3))
        playGoldenOnEngine(engine)
        _ = engine.finishSimmer()
        let cooked = engine.finishCooking()
        XCTAssertEqual(cooked?.quality, .good, "탄 잼은 한 단계만 살아난다")
    }

    func testSkippingSimmerKeepsTheHeatResult() {
        let engine = engineWithPot()
        engine.tickCooking(10)
        XCTAssertTrue(engine.simmerReady)
        engine.skipSimmer()
        XCTAssertNil(engine.simmerResult)
        let cooked = engine.finishCooking()
        XCTAssertNil(cooked?.simmer)
        XCTAssertEqual(cooked?.recipe?.id, "starlight-mist-jam")
    }

    func testStartingANewPotClearsTheOldSimmer() {
        let engine = engineWithPot()
        XCTAssertTrue(engine.startSimmer(seed: 31))
        XCTAssertNotNil(engine.simmer)
        engine.cancelCooking()
        XCTAssertNil(engine.simmer)
        XCTAssertNil(engine.simmerResult)
        XCTAssertNil(engine.cooking)
    }

    func testSimmerProgressAndRemaining() {
        var game = SimmerMinigame(seed: 9)
        game.tick(SimmerMinigame.duration / 2)
        XCTAssertEqual(game.progress, 0.5, accuracy: 0.01)
        XCTAssertEqual(game.remaining, SimmerMinigame.duration / 2, accuracy: 0.01)
        game.tick(SimmerMinigame.duration)
        XCTAssertEqual(game.progress, 1, accuracy: 0.0001)
        XCTAssertEqual(game.remaining, 0, accuracy: 0.0001)
    }
}
