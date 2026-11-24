import XCTest
import AcornForestCore

/// 「이웃의 오늘의 비밀 주문서」가 단서·점수·칭호·선반 장식까지 이어지는지 확인한다.
final class OrderBoardTests: XCTestCase {
    private func boardState(chapterThreeDone: Bool = true, cookedCount: Int = RecipeBook.base.count) -> GameState {
        var state = TestSupport.stockedState([])
        for chapter in [StoryChapter.prologue, .chapterOne, .chapterTwo] {
            state.markCompleted(chapter)
        }
        if chapterThreeDone {
            state.markCompleted(.chapterThree)
        }
        for character in CharacterID.coreNeighbours {
            state.addAffinity(AffinityLevel.greeting.rawValue, to: character)
        }
        for recipe in RecipeBook.base.prefix(cookedCount) {
            state.addCooked(recipeID: recipe.id, quality: .good, extraServings: 20)
        }
        return state
    }

    // MARK: - 열리는 시점

    func testBoardOpensAfterChapterThree() {
        XCTAssertFalse(DailyOrderBoard.isUnlocked(in: GameEngine.freshState()))
        XCTAssertNil(DailyOrderBoard.order(forDay: 10, in: GameEngine.freshState()))

        let notYet = TestSupport.engine(state: boardState(chapterThreeDone: false))
        XCTAssertFalse(notYet.orderBoardUnlocked)
        XCTAssertNil(notYet.todaysOrder)

        let tooFewJams = boardState(cookedCount: 1)
        XCTAssertFalse(DailyOrderBoard.isUnlocked(in: tooFewJams), "담근 잼이 하나뿐이면 주문서가 열리지 않는다")

        let engine = TestSupport.engine(state: boardState())
        XCTAssertTrue(engine.orderBoardUnlocked)
        XCTAssertNotNil(engine.todaysOrder)
    }

    func testOrdersNeedAGreetedNeighbour() {
        var state = boardState()
        state.affinity = CharacterID.allCases.map { AffinityState(character: $0) }
        XCTAssertNil(DailyOrderBoard.order(forDay: 3, in: state))
    }

    // MARK: - 단서

    func testOrderIsStableForTheSameDay() {
        let state = boardState()
        let first = DailyOrderBoard.order(forDay: 20_261_201, in: state)
        let second = DailyOrderBoard.order(forDay: 20_261_201, in: state)
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(DailyOrderBoard.order(forDay: 20_261_202, in: state)?.character,
                          DailyOrderBoard.order(forDay: 20_261_208, in: state)?.character)
    }

    func testClueAlwaysFitsAtLeastOneJamAndNarrowsTheChoice() {
        let state = boardState()
        for day in 1...40 {
            guard let order = DailyOrderBoard.order(forDay: day, in: state) else {
                return XCTFail("\(day)일에 주문서가 없다")
            }
            let matches = DailyOrderBoard.matchingRecipes(for: order, in: state)
            XCTAssertGreaterThanOrEqual(matches.count, 1, "\(day)일 단서에 맞는 잼이 없다")
            XCTAssertLessThanOrEqual(matches.count, 3, "\(day)일 단서가 너무 넓다: \(matches.map(\.name))")
            XCTAssertFalse(order.clue.isEmpty, "\(day)일 단서가 비었다")
            XCTAssertFalse(order.clueLine.isEmpty)
            XCTAssertFalse(order.note.isEmpty)
            XCTAssertTrue(CharacterID.coreNeighbours.contains(order.character))
        }
    }

    func testClueLinesReadLikeANeighbourSpeaking() {
        let state = boardState()
        let order = DailyOrderBoard.order(forDay: 5, in: state)!
        let line = order.clueLine
        XCTAssertTrue(line.contains("먹고 싶어") || line.contains("좋아"), line)
        if let ingredient = order.clue.needsIngredient {
            XCTAssertTrue(line.contains(ingredient.title), line)
        }
        if let warmth = order.clue.warmth {
            XCTAssertTrue(line.contains(DailyOrderBoard.warmthLine(warmth)), line)
        }
        XCTAssertTrue(order.note.contains("“"), order.note)
    }

    func testMatchesOnlyWhenEveryClueConditionHolds() {
        let jam = RecipeBook.recipe(id: "golden-fullmoon-jam")!
        let clue = OrderClue(warmth: 3, needsIngredient: .starMossShroom, avoidsIngredient: .dewberry, wantsMoonlight: true)
        XCTAssertTrue(DailyOrderBoard.matches(jam, clue: clue))
        XCTAssertFalse(DailyOrderBoard.matches(jam, clue: OrderClue(warmth: 1)))
        XCTAssertFalse(DailyOrderBoard.matches(jam, clue: OrderClue(avoidsIngredient: .starMossShroom)))
        XCTAssertFalse(DailyOrderBoard.matches(jam, clue: OrderClue(needsIngredient: .dewberry)))
        XCTAssertFalse(DailyOrderBoard.matches(RecipeBook.recipe(id: "dawn-dew-jam")!.self,
                                              clue: OrderClue(wantsMoonlight: true)))
    }

    // MARK: - 전달

    func testMatchingOrderScoresConsumesServingAndGivesEnergy() {
        let engine = TestSupport.engine(state: boardState())
        let order = try! XCTUnwrap(engine.todaysOrder)
        guard let recipe = DailyOrderBoard.matchingRecipes(for: order, in: engine.state).first else {
            return XCTFail("맞는 잼이 없다")
        }
        let servingsBefore = engine.state.servings(of: recipe.id)
        _ = engine.startGathering(at: .berryPatch, seed: 1)   // 기운을 하나 써 둔다
        TestSupport.catchEverything(engine)
        let energyBefore = engine.state.moonlightEnergy

        let outcome = engine.deliverOrder(recipeID: recipe.id)
        XCTAssertTrue(outcome.succeeded)
        XCTAssertTrue(outcome.matched, outcome.message)
        XCTAssertEqual(outcome.points, DailyOrderBoard.reward(for: order, streak: 0))
        XCTAssertEqual(engine.state.servings(of: recipe.id), servingsBefore - 1)
        XCTAssertEqual(engine.state.orders.count, 1)
        XCTAssertEqual(engine.state.orderStreak, 1)
        XCTAssertEqual(engine.state.orderPoints, outcome.points)
        XCTAssertEqual(engine.state.moonlightEnergy, energyBefore + GatherBalance.orderEnergy)
        XCTAssertTrue(outcome.energyGained)
    }

    func testOneOrderPerDay() {
        let engine = TestSupport.engine(state: boardState())
        let order = try! XCTUnwrap(engine.todaysOrder)
        let recipe = try! XCTUnwrap(DailyOrderBoard.matchingRecipes(for: order, in: engine.state).first)
        XCTAssertTrue(engine.deliverOrder(recipeID: recipe.id).succeeded)

        let again = engine.deliverOrder(recipeID: recipe.id)
        XCTAssertFalse(again.succeeded)
        XCTAssertTrue(again.message.contains("이미 마쳤어요"), again.message)
        XCTAssertEqual(engine.state.orders.count, 1)

        engine.simulateNextDay()
        let next = engine.deliverOrder(recipeID: "dawn-dew-jam")
        XCTAssertTrue(next.succeeded, next.message)
        XCTAssertEqual(engine.state.orders.count, 2, "다음 날에는 새 주문을 받는다")
    }

    func testWrongJamStillCountsButResetsTheStreak() {
        let engine = TestSupport.engine(state: boardState())
        let order = try! XCTUnwrap(engine.todaysOrder)
        let matching = Set(DailyOrderBoard.matchingRecipes(for: order, in: engine.state).map(\.id))
        guard let wrong = RecipeBook.base.first(where: { !matching.contains($0.id) }) else {
            return XCTFail("빗나갈 잼이 없다")
        }
        let outcome = engine.deliverOrder(recipeID: wrong.id)
        XCTAssertTrue(outcome.succeeded)
        XCTAssertFalse(outcome.matched)
        XCTAssertEqual(outcome.points, DailyOrderBoard.missPoints)
        XCTAssertEqual(engine.state.orderStreak, 0)
        XCTAssertEqual(engine.state.servings(of: wrong.id), 20, "없는 잼은 집히지 않는다")
    }

    func testDeliveringWithoutAServingIsRefused() {
        let engine = TestSupport.engine(state: boardState())
        let outcome = engine.deliverOrder(recipeID: "missing-jam")
        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(engine.state.orders.count, 0)
    }

    // MARK: - 누적 점수·칭호·장식

    func testPointsBuildTitlesAndTrophies() {
        XCTAssertEqual(OrderTitle.title(for: 0), .apprentice)
        XCTAssertEqual(OrderTitle.title(for: 30), .keeper)
        XCTAssertEqual(OrderTitle.title(for: 90), .artisan)
        XCTAssertEqual(OrderTitle.title(for: 180), .guardian)
        XCTAssertEqual(OrderTrophy.allCases.filter { 30 >= $0.threshold }.map(\.rawValue), [OrderTrophy.moonRibbon.rawValue])
        XCTAssertEqual(DailyOrderBoard.newlyUnlockedTrophies(at: 90, alreadyOwned: []).count, 2)
        XCTAssertEqual(DailyOrderBoard.newlyUnlockedTrophies(at: 90,
                                                             alreadyOwned: [OrderTrophy.moonRibbon.rawValue]).count, 1)
    }

    func testRepeatedOrdersReachTheFirstTrophy() {
        var state = boardState()
        state.add(GameState.startingBasket)
        let engine = TestSupport.engine(state: state)
        var days = 0
        while engine.state.unlockedTrophies.isEmpty && days < 10 {
            if let order = engine.todaysOrder,
               let recipe = DailyOrderBoard.matchingRecipes(for: order, in: engine.state)
                .first(where: { engine.state.servings(of: $0.id) > 0 }) {
                _ = engine.deliverOrder(recipeID: recipe.id)
            }
            if !engine.state.unlockedTrophies.isEmpty { break }
            engine.simulateNextDay()
            days += 1
        }
        XCTAssertFalse(engine.state.unlockedTrophies.isEmpty)
        XCTAssertTrue(engine.state.unlockedTrophies.contains(.moonRibbon))
        XCTAssertEqual(engine.state.orderTitle, .keeper)
        XCTAssertTrue(engine.orderLine.contains("주문 점수"))
    }

    func testOrderStateSurvivesSaveRoundTrip() throws {
        var state = boardState()
        state.orderPoints = 96
        state.orderStreak = 2
        state.bestOrderStreak = 3
        state.orderTrophies = [OrderTrophy.moonRibbon.rawValue]
        state.orders = [OrderRecord(day: 20_261_201, character: .tori,
                                    recipeID: "dawn-dew-jam", matched: true, points: 14)]
        state.moonlightEnergy = 2
        state.energyDay = 20_261_201
        state.giftDay = 20_261_201
        state.giftCounts = ["tori": 2]
        let data = try SaveCodec.encode(SaveFile(state: state))
        let restored = try SaveCodec.decode(data)
        XCTAssertEqual(restored.state.orderPoints, 96)
        XCTAssertEqual(restored.state.orders.count, 1)
        XCTAssertEqual(restored.state.orderTrophies, [OrderTrophy.moonRibbon.rawValue])
        XCTAssertEqual(restored.state.moonlightEnergy, 2)
        XCTAssertEqual(restored.state.giftCounts["tori"], 2)
        XCTAssertEqual(restored.state.unlockedTrophies, [.moonRibbon])
    }
}
