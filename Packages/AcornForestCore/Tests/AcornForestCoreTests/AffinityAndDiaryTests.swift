import XCTest
import AcornForestCore

final class AffinityAndDiaryTests: XCTestCase {
    func testLevelThresholds() {
        XCTAssertEqual(AffinitySystem.level(for: 0), .shy)
        XCTAssertEqual(AffinitySystem.level(for: 19), .shy)
        XCTAssertEqual(AffinitySystem.level(for: 20), .greeting)
        XCTAssertEqual(AffinitySystem.level(for: 44), .greeting)
        XCTAssertEqual(AffinitySystem.level(for: 45), .close)
        XCTAssertEqual(AffinitySystem.level(for: 69), .close)
        XCTAssertEqual(AffinitySystem.level(for: 70), .family)
        XCTAssertEqual(AffinitySystem.level(for: 100), .family)
    }

    func testAffinityIsClampedToMaximum() {
        XCTAssertEqual(AffinitySystem.clamped(130), 100)
        XCTAssertEqual(AffinitySystem.clamped(-5), 0)
        var state = GameEngine.freshState()
        state.addAffinity(500, to: .tori)
        XCTAssertEqual(state.affinityPoints(for: .tori), 100)
        XCTAssertEqual(state.affinityLevel(for: .tori), .family)
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
        XCTAssertEqual(favoritePoints, 12)
        XCTAssertEqual(likedPoints, 7)
        XCTAssertEqual(dislikedPoints, 1)
        XCTAssertGreaterThan(favoritePoints, likedPoints)
    }

    func testMemoryEntriesUnlockByLevel() {
        XCTAssertTrue(ForestDiary.memoryEntriesUnlocked(for: .mong, level: .shy).isEmpty)
        XCTAssertEqual(ForestDiary.memoryEntriesUnlocked(for: .mong, level: .greeting).count, 1)
        XCTAssertEqual(ForestDiary.memoryEntriesUnlocked(for: .mong, level: .close).count, 2)
        XCTAssertEqual(ForestDiary.memoryEntriesUnlocked(for: .mong, level: .family).count, 2)
    }

    func testDiaryCatalogIsComplete() {
        XCTAssertEqual(ForestDiary.entries(kind: .recipe).count, RecipeBook.all.count)
        XCTAssertEqual(ForestDiary.entries(kind: .memory).count, CharacterID.allCases.count * 2)
        XCTAssertEqual(ForestDiary.entries(kind: .chapter).count, StoryChapter.allCases.count)
        XCTAssertEqual(ForestDiary.entries(kind: .festival).count, 1)
        let ids = ForestDiary.entries.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
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
