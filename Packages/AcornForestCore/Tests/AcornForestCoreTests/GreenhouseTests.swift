import XCTest
import AcornForestCore

final class GreenhouseTests: XCTestCase {
    private func greenhouseState() -> GameState {
        var state = TestSupport.stockedState([
            ItemStack(.cherryHoney, 2),
            ItemStack(.dewberry, 2),
            ItemStack(.mapleSap, 1),
            ItemStack(.starMossShroom, 1),
            ItemStack(.snowBlossom, 1),
            ItemStack(.moonlitDew, 1),
            ItemStack(.moonflakeSpice, 1)
        ])
        state.markCompleted(.prologue)
        state.markCompleted(.chapterOne)
        state.markCompleted(.chapterTwo)
        state.markCompleted(.chapterThree)
        state.markCompleted(.epilogue)
        state.grant(.greenhouse)
        return state
    }

    func testThreeSeasonalRecipesExist() {
        XCTAssertEqual(GreenhouseRecipes.all.count, 3)
        for recipe in GreenhouseRecipes.all {
            XCTAssertEqual(recipe.lockedByPack, .greenhouse)
            XCTAssertTrue((2...3).contains(recipe.ingredients.count))
            XCTAssertFalse(recipe.story.isEmpty)
        }
        XCTAssertEqual(RecipeBook.all.count, 12, "기본 7 + 계절 3 + 비밀 2")
        let keys = RecipeBook.all.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "조합이 겹치면 안 된다")
    }

    func testSeasonalRecipeNeedsThePack() {
        var state = TestSupport.stockedState([ItemStack(.cherryHoney, 1), ItemStack(.dewberry, 1)])
        let withoutPack = TestSupport.engine(state: state)
        XCTAssertNil(withoutPack.recipePreview(for: [.cherryHoney, .dewberry]))
        XCTAssertTrue(withoutPack.startCooking(ingredients: [.cherryHoney, .dewberry]))
        XCTAssertNil(withoutPack.finishCooking()?.recipe)

        state.add(.cherryHoney, count: 1)
        state.add(.dewberry, count: 1)
        state.grant(.greenhouse)
        let withPack = TestSupport.engine(state: state)
        XCTAssertEqual(withPack.recipePreview(for: [.cherryHoney, .dewberry])?.id, GreenhouseRecipes.springID)
        XCTAssertTrue(withPack.startCooking(ingredients: [.cherryHoney, .dewberry]))
        let outcome = withPack.finishCooking()
        XCTAssertEqual(outcome?.recipe?.id, GreenhouseRecipes.springID)
        XCTAssertTrue(withPack.state.hasDiary(ForestDiary.recipeEntryID(for: GreenhouseRecipes.springID)))
    }

    func testUnCookedListGrowsWithThePack() {
        let plain = TestSupport.stockedState([])
        let withPack = greenhouseState()
        XCTAssertLessThan(RecipeBook.unCooked(in: plain).count, RecipeBook.unCooked(in: withPack).count)
        XCTAssertEqual(RecipeBook.visibleRecipes(for: plain).count, 7)
        XCTAssertEqual(RecipeBook.visibleRecipes(for: withPack).count, 10)
    }

    func testNewNeighboursAreFullyDefined() {
        XCTAssertEqual(CharacterID.coreNeighbours.count, 4)
        XCTAssertEqual(CharacterID.expansionNeighbours, [.luna, .coco])
        for character in CharacterID.expansionNeighbours {
            XCTAssertTrue(character.isExpansionCharacter)
            XCTAssertFalse(character.name.isEmpty)
            XCTAssertFalse(character.species.isEmpty)
            XCTAssertFalse(character.personality.isEmpty)
            XCTAssertFalse(character.wish.isEmpty)
            XCTAssertNotNil(RecipeBook.recipe(id: character.favoriteRecipeID), "\(character.name)의 최애 잼")
            XCTAssertFalse(character.likedRecipeIDs.isEmpty)
            XCTAssertNotEqual(character.favoriteRecipeID, character.likedRecipeIDs.first)
        }
        XCTAssertEqual(CharacterID.luna.favoriteRecipeID, GreenhouseRecipes.winterID)
        XCTAssertEqual(CharacterID.coco.favoriteRecipeID, GreenhouseRecipes.springID)
    }

    func testTalkingRequiresPackAndGivesAffinityOnce() {
        let withoutPack = TestSupport.engine()
        XCTAssertNil(withoutPack.talk(to: .luna))

        let engine = TestSupport.engine(state: greenhouseState())
        let first = engine.talk(to: .luna)
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.gain, GreenhouseDialogue.affinityGain)
        XCTAssertTrue(first?.isFirstTime ?? false)
        XCTAssertEqual(engine.state.affinityPoints(for: .luna), GreenhouseDialogue.affinityGain)
        XCTAssertTrue(engine.state.hasTalked(to: .luna))

        let second = engine.talk(to: .luna)
        XCTAssertEqual(second?.gain, 0, "두 번째 대화는 호감도를 더 주지 않는다")
        XCTAssertFalse(second?.isFirstTime ?? true)
        XCTAssertEqual(engine.state.affinityPoints(for: .luna), GreenhouseDialogue.affinityGain)
    }

    func testCloseDialogueUnlocksAtCloseLevel() {
        var state = greenhouseState()
        state.addAffinity(50, to: .coco)
        state.markTalked(to: .coco)
        let engine = TestSupport.engine(state: state)
        let scene = engine.talk(to: .coco)
        XCTAssertEqual(scene?.scene.id, GreenhouseDialogue.cocoClose.id)
        XCTAssertEqual(scene?.gain, 0, "이미 읽은 대화는 호감도를 더 주지 않는다")
    }

    func testGreenhouseWelcomeHappensOnce() {
        let engine = TestSupport.engine(state: greenhouseState())
        let first = engine.greenhouseWelcome()
        XCTAssertTrue(first?.isFirstTime ?? false)
        XCTAssertEqual(first?.gain, 4)
        XCTAssertTrue(engine.state.hasFlag("greenhouse.opened"))
        XCTAssertEqual(engine.state.affinityPoints(for: .luna), 4)
        let second = engine.greenhouseWelcome()
        XCTAssertFalse(second?.isFirstTime ?? true)
        XCTAssertEqual(second?.gain, 0)
    }

    func testDialogueDataIsWellFormed() {
        let scenes = GreenhouseDialogue.all
        XCTAssertGreaterThanOrEqual(scenes.count, 4)
        let ids = scenes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        let lineIDs = scenes.flatMap { $0.lines.map(\.id) }
        XCTAssertEqual(Set(lineIDs).count, lineIDs.count, "대화 id 중복")
        for scene in scenes {
            XCTAssertGreaterThanOrEqual(scene.lines.count, 3, scene.title)
            XCTAssertFalse(scene.closingThought.isEmpty, scene.title)
        }
        XCTAssertNotNil(GreenhouseDialogue.scene(id: GreenhouseDialogue.greetingID))
    }

    func testGiftingSeasonalJamRaisesLunaAffinity() {
        var state = greenhouseState()
        state.addCooked(recipeID: GreenhouseRecipes.winterID, quality: .good)
        let engine = TestSupport.engine(state: state)
        let outcome = engine.gift(recipeID: GreenhouseRecipes.winterID, to: .luna)
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.gain, 12, "루나의 최애 잼")
    }

    func testGreenhouseSeasonsAndDiary() {
        XCTAssertEqual(GreenhouseRecipes.Season.allCases.count, 4)
        XCTAssertEqual(GreenhouseRecipes.Season.spring.ingredient, .cherryHoney)
        XCTAssertEqual(GreenhouseRecipes.Season.winter.ingredient, .snowBlossom)
        XCTAssertTrue(ForestDiary.expandedEntries.contains { $0.id == "memory.luna.1" })
        XCTAssertTrue(ForestDiary.expandedEntries.contains { $0.id == "recipe.\(GreenhouseRecipes.winterID)" })
        XCTAssertEqual(ForestDiary.totalCount, 21, "본편 일기장은 그대로 21칸")
    }
}
