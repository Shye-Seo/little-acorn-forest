import XCTest
import AcornForestCore

final class AffinityAndDiaryTests: XCTestCase {
    func testLevelThresholds() {
        XCTAssertEqual(AffinityLevel.greeting.rawValue, 20)
        XCTAssertEqual(AffinityLevel.close.rawValue, 150)
        XCTAssertEqual(AffinityLevel.family.rawValue, 210)
        XCTAssertEqual(AffinitySystem.level(for: 0), .shy)
        XCTAssertEqual(AffinitySystem.level(for: 19), .shy)
        XCTAssertEqual(AffinitySystem.level(for: 20), .greeting)
        XCTAssertEqual(AffinitySystem.level(for: 149), .greeting)
        XCTAssertEqual(AffinitySystem.level(for: 150), .close)
        XCTAssertEqual(AffinitySystem.level(for: 209), .close)
        XCTAssertEqual(AffinitySystem.level(for: 210), .family)
        XCTAssertEqual(AffinitySystem.level(for: AffinitySystem.maximum), .family)
    }

    func testAffinityIsClampedToMaximum() {
        XCTAssertEqual(AffinitySystem.maximum, 240)
        XCTAssertEqual(AffinitySystem.clamped(200), 200)
        XCTAssertEqual(AffinitySystem.clamped(999), 240)
        XCTAssertEqual(AffinitySystem.clamped(-5), 0)
        var state = GameEngine.freshState()
        state.addAffinity(500, to: .tori)
        XCTAssertEqual(state.affinityPoints(for: .tori), 240)
        XCTAssertEqual(state.affinityLevel(for: .tori), .family)
    }

    func testDailyGiftDecay() {
        XCTAssertEqual(AffinitySystem.dailyGiftFactor(forGiftIndex: 0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(AffinitySystem.dailyGiftFactor(forGiftIndex: 1), 0.5, accuracy: 0.0001)
        XCTAssertEqual(AffinitySystem.dailyGiftFactor(forGiftIndex: 2), 0.3, accuracy: 0.0001)
        XCTAssertEqual(AffinitySystem.dailyGiftFactor(forGiftIndex: 3), 0.15, accuracy: 0.0001)
        XCTAssertEqual(AffinitySystem.dailyGiftFactor(forGiftIndex: 9), 0.15, accuracy: 0.0001,
                       "같은 날 더 많이 건네도 이 아래로는 내려가지 않는다")
    }

    func testSecondGiftOfTheDayIsDiminished() {
        var state = TestSupport.stockedState([])
        state.addCooked(recipeID: "meteor-berry-compote", quality: .perfect, extraServings: 2)
        let engine = TestSupport.engine(state: state)
        let first = engine.gift(recipeID: "meteor-berry-compote", to: .tori)
        let second = engine.gift(recipeID: "meteor-berry-compote", to: .tori)
        XCTAssertEqual(first.gain, 15, "최애 잼 + 완벽한 온기")
        XCTAssertEqual(second.gain, 8, "같은 날 두 번째는 50%만")
        XCTAssertTrue(second.wasDiminished)
        XCTAssertTrue(second.message.contains("잦아들었"))

        engine.simulateNextDay()
        state = engine.state
        XCTAssertEqual(state.giftsGiven(to: .tori, day: state.currentDay(at: engine.now())), 0,
                       "날이 바뀌면 오늘의 선물 수가 처음부터 다시 센다")
        let third = engine.gift(recipeID: "meteor-berry-compote", to: .tori)
        XCTAssertEqual(third.gain, 15)
    }

    func testGiftPreferenceOrdering() {
        guard let favorite = RecipeBook.recipe(id: CharacterID.tori.favoriteRecipeID),
              let likedID = CharacterID.tori.likedRecipeIDs.first,
              let liked = RecipeBook.recipe(id: likedID),
              let neutral = RecipeBook.recipe(id: "moonshadow-herb-jelly") else {
            return XCTFail("레시피를 찾지 못했다")
        }
        let favoritePoints = AffinitySystem.baseGiftPoints(recipe: favorite, for: .tori)
        let likedPoints = AffinitySystem.baseGiftPoints(recipe: liked, for: .tori)
        let dislikedPoints = AffinitySystem.baseGiftPoints(recipe: neutral, for: .tori)
        XCTAssertEqual(favoritePoints, AffinitySystem.favoritePoints)
        XCTAssertEqual(likedPoints, AffinitySystem.likedPoints)
        XCTAssertEqual(dislikedPoints, AffinitySystem.dislikedPoints)
        XCTAssertGreaterThan(favoritePoints, likedPoints)
    }

    func testMemoryEntriesUnlockByLevel() {
        XCTAssertTrue(ForestDiary.memoryEntriesUnlocked(for: .mong, level: .shy).isEmpty)
        XCTAssertEqual(ForestDiary.memoryEntriesUnlocked(for: .mong, level: .greeting).count, 1)
        XCTAssertEqual(ForestDiary.memoryEntriesUnlocked(for: .mong, level: .close).count, 2)
        XCTAssertEqual(ForestDiary.memoryEntriesUnlocked(for: .mong, level: .family).count, 2)
    }

    func testDiaryCatalogIsComplete() {
        XCTAssertEqual(ForestDiary.entries(kind: .recipe).count, RecipeBook.base.count)
        XCTAssertEqual(ForestDiary.entries(kind: .memory).count, CharacterID.coreNeighbours.count * 2)
        XCTAssertEqual(ForestDiary.entries(kind: .chapter).count, StoryChapter.allCases.count)
        XCTAssertEqual(ForestDiary.entries(kind: .festival).count, 1)
        let ids = ForestDiary.entries.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ForestDiary.totalCount, 21)
    }

    func testExpandedDiaryCoversGreenhouseAndSecretRecipes() {
        let extras = ForestDiary.expandedEntries
        XCTAssertEqual(extras.filter { $0.kind == .recipe }.count,
                       GreenhouseRecipes.all.count + SecretRecipeBook.all.count)
        XCTAssertEqual(extras.filter { $0.kind == .memory }.count,
                       CharacterID.expansionNeighbours.count * 2)
        let ids = ForestDiary.allEntries.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "본편과 확장 기록의 id가 겹치면 안 된다")
        XCTAssertEqual(ForestDiary.expandedCount,
                       GreenhouseRecipes.all.count + SecretRecipeBook.all.count
                       + CharacterID.expansionNeighbours.count * 2)
    }

    func testGiftConsumesServingAndRaisesAffinity() {
        var state = TestSupport.stockedState([])
        state.addCooked(recipeID: "meteor-berry-compote", quality: .good)
        let engine = TestSupport.engine(state: state)
        let outcome = engine.gift(recipeID: "meteor-berry-compote", to: .tori)
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.gain, 12)
        XCTAssertEqual(engine.state.affinityPoints(for: .tori), 12)
        XCTAssertEqual(engine.state.servings(of: "meteor-berry-compote"), 0)
        XCTAssertEqual(engine.state.stats.gifts, 1)
    }

    func testPerfectDishAddsBonusAndUnlocksMemory() {
        var state = TestSupport.stockedState([])
        state.addCooked(recipeID: "meteor-berry-compote", quality: .perfect)
        state.addAffinity(18, to: .tori)
        let engine = TestSupport.engine(state: state)
        let outcome = engine.gift(recipeID: "meteor-berry-compote", to: .tori)
        XCTAssertEqual(outcome.gain, 15)
        XCTAssertTrue(outcome.didLevelUp)
        XCTAssertEqual(outcome.levelAfter, .greeting)
        XCTAssertTrue(engine.state.hasDiary("memory.tori.1"))
    }

    func testGiftWithoutDishFails() {
        let engine = TestSupport.engine(state: TestSupport.stockedState([]))
        let outcome = engine.gift(recipeID: "meteor-berry-compote", to: .rubi)
        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.gain, 0)
        XCTAssertEqual(engine.state.affinityPoints(for: .rubi), 0)
    }

    func testDiaryProgressCountsUnlockedEntries() {
        var state = GameEngine.freshState()
        XCTAssertEqual(state.diaryProgress.unlocked, 0)
        XCTAssertEqual(state.diaryProgress.total, ForestDiary.totalCount)
        state.unlockDiary("recipe.dawn-dew-jam")
        XCTAssertEqual(state.diaryProgress.unlocked, 1)
        XCTAssertEqual(state.diaryProgress.ratio, 1.0 / Double(ForestDiary.totalCount), accuracy: 0.0001)
    }

    func testUnlockDiaryReportsOnlyNewEntries() {
        var state = GameEngine.freshState()
        XCTAssertTrue(state.unlockDiary("chapter.prologue"))
        XCTAssertFalse(state.unlockDiary("chapter.prologue"))
        let newly = state.unlockDiary(["chapter.prologue", "chapter.chapterOne"])
        XCTAssertEqual(newly, ["chapter.chapterOne"])
    }
}
