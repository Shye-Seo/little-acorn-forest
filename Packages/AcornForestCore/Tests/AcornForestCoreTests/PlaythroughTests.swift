import XCTest
import AcornForestCore

/// 실제 플레이를 흉내 내어, 새 밸런스에서 이야기가 며칠 만에 끝나는지 확인한다.
final class PlaythroughTests: XCTestCase {
    /// 하루치 플레이: 채집 → 잼 → 선물 → 주문서.
    private struct Simulation {
        let engine: GameEngine
        var days = 0
        var gathers = 0
        var cooks = 0
        var gifts = 0

        init(engine: GameEngine) {
            self.engine = engine
        }

        mutating func gatherAll() {
            let places: [ForestLocation] = [.berryPatch, .fireflyPond, .owlLibrary, .cabinKitchen]
            var index = 0
            var focusUsed = 0
            var rounds = 0
            while rounds < 40 {
                rounds += 1
                if engine.state.canGather {
                    let place = places[index % places.count]
                    index += 1
                    guard engine.startGathering(at: place, seed: UInt64(index * 7 + 1)) else { break }
                    TestSupport.catchEverything(engine)
                    gathers += 1
                    continue
                }
                // 기운이 떨어지면 모닥불에 앉아 한 칸씩 되찾는다(하루 상한까지).
                guard focusUsed < GatherBalance.focusEnergyCap,
                      engine.startFocus(.five, track: .rain) else { break }
                engine.tickFocus(300)
                _ = engine.finishFocus()
                focusUsed += 1
            }
        }

        mutating func cookEverything() {
            for recipe in RecipeBook.visibleRecipes(for: engine.state) {
                while engine.state.canAfford(recipe.ingredients)
                    && engine.state.servings(of: recipe.id) < 3 {
                    guard engine.startCooking(ingredients: recipe.ingredients) else { break }
                    TestSupport.stirToPerfect(engine)
                    if engine.simmerReady {
                        _ = engine.startSimmer(seed: UInt64(cooks + 3))
                        playGolden()
                    }
                    _ = engine.finishCooking()
                    cooks += 1
                }
            }
        }

        mutating func playGolden() {
            guard let seed = engine.simmer?.seed else { return }
            var steps = 0
            while steps < 4000 {
                steps += 1
                guard let game = engine.simmer, !game.isFinished else { break }
                if let request = game.currentRequest, game.isAwaitingPress, request.isGolden(game.needle) {
                    _ = engine.pressSimmer(request.action)
                    continue
                }
                engine.tickSimmer(0.01)
            }
            _ = seed
            _ = engine.finishSimmer()
        }

        mutating func giftAround() {
            for character in CharacterID.coreNeighbours {
                var rounds = 0
                while engine.state.affinityLevel(for: character) < .close, rounds < 2 {
                    let favourite = character.favoriteRecipeID
                    if engine.state.servings(of: favourite) > 0 {
                        _ = engine.gift(recipeID: favourite, to: character)
                    } else if let record = engine.state.cooked.first(where: { $0.servings > 0 }) {
                        _ = engine.gift(recipeID: record.recipeID, to: character)
                    } else {
                        break
                    }
                    rounds += 1
                    gifts += 1
                }
            }
        }

        mutating func deliverOrder() {
            guard engine.orderBoardUnlocked, engine.todaysOrderRecord == nil,
                  let order = engine.todaysOrder,
                  let recipe = DailyOrderBoard.matchingRecipes(for: order, in: engine.state)
                    .first(where: { engine.state.servings(of: $0.id) > 0 }) else { return }
            _ = engine.deliverOrder(recipeID: recipe.id)
        }

        mutating func playStory() {
            _ = engine.refreshChapterAvailability()
            var guardCount = 0
            while let chapter = engine.nextChapterToPlay, guardCount < 12 {
                guardCount += 1
                let step = TestSupport.playChapter(engine, chapter)
                if case .blocked = step { break }
                _ = engine.refreshChapterAvailability()
            }
        }

        mutating func run(until condition: () -> Bool, limit: Int = 40) {
            while !condition() && days < limit {
                playStory()
                gatherAll()
                cookEverything()
                giftAround()
                deliverOrder()
                playStory()
                if condition() { break }
                engine.simulateNextDay()
                days += 1
            }
        }
    }

    func testStoryTakesSeveralDaysOfRealPlay() {
        let engine = TestSupport.engine()
        var sim = Simulation(engine: engine)

        sim.run(until: { engine.isStoryComplete })
        XCTAssertTrue(engine.isStoryComplete, "40일 안에 이야기가 끝나지 않았다 (day \(sim.days))")
        XCTAssertGreaterThanOrEqual(sim.days, 4, "본편이 나흘보다 짧게 끝나면 밸런스가 너무 얕다: \(sim.days)일")
        XCTAssertLessThanOrEqual(sim.days, 25, "한 달을 넘기면 지나치게 늘어진다: \(sim.days)일")
        XCTAssertEqual(engine.state.completedChapters.count, StoryChapter.allCases.count)
        print("PLAYTHROUGH days=\(sim.days) gathers=\(sim.gathers) cooks=\(sim.cooks) gifts=\(sim.gifts) orders=\(engine.state.orders.count)")
    }

    func testPostStoryContentKeepsGoing() {
        let engine = TestSupport.engine()
        var sim = Simulation(engine: engine)
        sim.run(until: { engine.isStoryComplete })
        let daysAfterStory = 4
        for _ in 0..<daysAfterStory {
            sim.gatherAll()
            sim.cookEverything()
            sim.deliverOrder()
            engine.simulateNextDay()
        }
        XCTAssertGreaterThanOrEqual(engine.state.orders.count, 3, "이야기가 끝난 뒤에도 주문서가 하루씩 굴러간다")
        XCTAssertGreaterThan(engine.state.orderPoints, 0)
        XCTAssertFalse(engine.state.orderTrophies.isEmpty, "장식까지 열려야 한다: \(engine.state.orderPoints)점")
        XCTAssertGreaterThan(engine.state.fireflyDust, 0)
        print("POST-STORY orders=\(engine.state.orders.count) points=\(engine.state.orderPoints) trophies=\(engine.state.orderTrophies)")
    }
}
