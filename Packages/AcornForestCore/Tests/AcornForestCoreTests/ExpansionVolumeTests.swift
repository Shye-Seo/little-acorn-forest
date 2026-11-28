import XCTest
import AcornForestCore

/// 2026-11 볼륨 확장분(재료 6종·레시피 14종·심야 구역 2곳·방문 손님 2명·특별 의뢰·도감 마스터리)을 검증한다.
final class ExpansionVolumeTests: XCTestCase {
    private func completedStoryState(_ stacks: [ItemStack] = []) -> GameState {
        var state = TestSupport.stockedState(stacks)
        for chapter in StoryChapter.ordered {
            state.markCompleted(chapter)
        }
        return state
    }

    // MARK: - 재료와 레시피 볼륨

    func testIngredientCatalogDoublesWithFantasyAdditions() {
        XCTAssertEqual(Ingredient.allCases.count, 14, "기본 4 + 확장 10")
        XCTAssertEqual(Ingredient.basic.count, 4)
        XCTAssertEqual(Ingredient.midnight.count, 4)
        for ingredient in Ingredient.allCases {
            XCTAssertFalse(ingredient.title.isEmpty, ingredient.rawValue)
            XCTAssertFalse(ingredient.note.isEmpty, ingredient.rawValue)
            XCTAssertFalse(ingredient.emoji.isEmpty, ingredient.rawValue)
            XCTAssertGreaterThan(ingredient.gatherPoints, 0, ingredient.rawValue)
            XCTAssertFalse(ingredient.englishTitle.isEmpty, ingredient.rawValue)
            XCTAssertFalse(ingredient.paletteName.isEmpty, ingredient.rawValue)
        }
        // 새 재료는 모두 판타지 이름이며 현실 요리 이름을 쓰지 않는다.
        let newOnes = Ingredient.midnight + [.emberQuince, .frostFernSpore]
        XCTAssertEqual(newOnes.count, 6)
        for ingredient in newOnes {
            XCTAssertTrue(ingredient.isExpansionIngredient, ingredient.title)
            XCTAssertNotNil(ingredient.sourceLocation, ingredient.title)
        }
    }

    func testRecipeConstantsPointAtRealRecipes() {
        for id in MidnightRecipes.ids {
            XCTAssertNotNil(RecipeBook.recipe(id: id), id)
        }
        for id in SecretRecipeBook.ids {
            XCTAssertNotNil(RecipeBook.recipe(id: id), id)
        }
        XCTAssertEqual(MidnightRecipes.recipe(id: MidnightRecipes.bellCottonID)?.id, MidnightRecipes.bellCottonID)
        XCTAssertEqual(MidnightRecipes.recipe(id: MidnightRecipes.cometFrostID)?.id, MidnightRecipes.cometFrostID)
        XCTAssertEqual(SecretRecipeBook.recipe(id: SecretRecipeBook.midnightFarewellID)?.id,
                       SecretRecipeBook.midnightFarewellID)
        XCTAssertEqual(GreenhouseRecipes.recipe(id: GreenhouseRecipes.emberQuinceID)?.id,
                       GreenhouseRecipes.emberQuinceID)
        // 이웃의 최애·호불호가 모두 실제 레시피를 가리킨다.
        for character in CharacterID.allCases {
            XCTAssertNotNil(RecipeBook.recipe(id: character.favoriteRecipeID), character.name)
            for id in character.likedRecipeIDs + character.dislikedRecipeIDs {
                XCTAssertNotNil(RecipeBook.recipe(id: id), "\(character.name): \(id)")
            }
        }
    }

    func testRecipeBookGrowsToTwentySixWithUniqueCombinations() {
        XCTAssertEqual(RecipeBook.base.count, 8)
        XCTAssertEqual(GreenhouseRecipes.all.count, 5)
        XCTAssertEqual(MidnightRecipes.all.count, 9)
        XCTAssertEqual(SecretRecipeBook.all.count, 4)
        XCTAssertEqual(RecipeBook.all.count, 26)

        let keys = RecipeBook.all.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "조합이 겹치면 안 된다")
        let ids = RecipeBook.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "레시피 id가 겹치면 안 된다")
        for recipe in RecipeBook.all {
            XCTAssertTrue((2...3).contains(recipe.ingredients.count), recipe.name)
            XCTAssertFalse(recipe.story.isEmpty, recipe.name)
        }
    }

    func testCodexVolumeIsMoreThanDoubleTheOriginalTwenty() {
        // 확장 전: 재료 8 + 레시피 12 = 20칸. 확장 후: 재료 14 + 레시피 26 = 40칸.
        let before = 8 + 12
        let after = Ingredient.allCases.count + RecipeBook.all.count
        XCTAssertEqual(after, 40)
        XCTAssertGreaterThanOrEqual(after, before * 2, "도감 볼륨이 2배 이상이어야 한다")
    }

    func testMidnightRecipesStayHiddenUntilTheStoryEnds() {
        let before = TestSupport.stockedState([])
        let beforeIDs = Set(RecipeBook.visibleRecipes(for: before).map(\.id))
        for recipe in MidnightRecipes.all {
            XCTAssertFalse(beforeIDs.contains(recipe.id), recipe.name)
        }
        XCTAssertNil(RecipeBook.recipe(
            for: [.nightBellFlower, .mothDustSugar],
            unlockedSecretIDs: [],
            includesSeasonal: false,
            includesMidnight: before.isStoryComplete
        ))

        let after = completedStoryState()
        let afterIDs = Set(RecipeBook.visibleRecipes(for: after).map(\.id))
        for recipe in MidnightRecipes.all {
            XCTAssertTrue(afterIDs.contains(recipe.id), recipe.name)
        }
        XCTAssertEqual(
            RecipeBook.recipe(
                for: [.mothDustSugar, .nightBellFlower],
                unlockedSecretIDs: [],
                includesSeasonal: false,
                includesMidnight: after.isStoryComplete
            )?.id,
            MidnightRecipes.bellCottonID
        )
    }

    func testSeasonalRecipesUseTheNewGreenhouseIngredients() {
        let seasonal = GreenhouseRecipes.all
        XCTAssertTrue(seasonal.contains { $0.id == GreenhouseRecipes.emberQuinceID })
        XCTAssertTrue(seasonal.contains { $0.id == GreenhouseRecipes.frostFernID })
        XCTAssertTrue(seasonal.allSatisfy { $0.lockedByPack == .greenhouse })
        XCTAssertEqual(GreenhouseRecipes.Season.autumn.secondaryIngredient, .emberQuince)
        XCTAssertEqual(GreenhouseRecipes.Season.winter.secondaryIngredient, .frostFernSpore)
    }

    // MARK: - 심야 구역

    func testMidnightZoneUnlocksOnlyAfterTheEnding() {
        let before = TestSupport.engine(state: TestSupport.stockedState([]))
        XCTAssertFalse(before.isLocationUnlocked(.mothLanternBridge))
        XCTAssertFalse(before.isLocationUnlocked(.starSaltSpring))
        XCTAssertTrue(before.lockMessage(for: .mothLanternBridge).contains("심야"))
        XCTAssertFalse(before.startGathering(at: .starSaltSpring))

        let after = TestSupport.engine(state: completedStoryState())
        XCTAssertTrue(after.isLocationUnlocked(.mothLanternBridge))
        XCTAssertTrue(after.isLocationUnlocked(.starSaltSpring))
        XCTAssertTrue(after.visibleIngredients.contains(.mothDustSugar))
        XCTAssertTrue(after.visibleIngredients.contains(.cometFeather))
    }

    func testMidnightZoneIsFreeAndGatherable() {
        XCTAssertEqual(ForestLocation.allCases.count, 9)
        for location in [ForestLocation.mothLanternBridge, .starSaltSpring] {
            XCTAssertNil(location.requiredPack)
            XCTAssertTrue(location.isGatherable)
            XCTAssertTrue(location.requiresStoryComplete)
            XCTAssertFalse(location.requiresFullMoon)
            XCTAssertEqual(GatherBalance.totalWeight(of: location.dropTable), 100)
            XCTAssertTrue(location.ingredientPool.contains(where: \.isMidnightIngredient))
        }
    }

    // MARK: - 방문 손님과 호감도 대사

    func testVisitorNeighboursArriveAfterTheStory() {
        XCTAssertEqual(CharacterID.allCases.count, 8)
        XCTAssertEqual(CharacterID.visitorNeighbours, [.dallae, .moru])
        let before = TestSupport.engine(state: TestSupport.stockedState([]))
        XCTAssertFalse(before.visibleCharacters.contains(.dallae))
        XCTAssertNil(before.talk(to: .dallae))

        let after = TestSupport.engine(state: completedStoryState())
        XCTAssertTrue(after.visibleCharacters.contains(.dallae))
        XCTAssertTrue(after.visibleCharacters.contains(.moru))
        XCTAssertEqual(after.visibleCharacters.count, 6, "본편 4 + 심야 손님 2 (온실지기는 확장팩 필요)")

        var withGreenhouse = completedStoryState()
        withGreenhouse.grant(.greenhouse)
        XCTAssertEqual(TestSupport.engine(state: withGreenhouse).visibleCharacters.count, 8)

        let first = after.talk(to: .dallae)
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.gain, MidnightGuests.affinityGain)
        XCTAssertTrue(first?.isFirstTime ?? false)
        XCTAssertEqual(after.state.affinityPoints(for: .dallae), MidnightGuests.affinityGain)
        XCTAssertEqual(after.talk(to: .dallae)?.gain, 0, "두 번째 대화는 호감도를 더 주지 않는다")
    }

    func testMidnightWelcomeHappensOnce() {
        let engine = TestSupport.engine(state: completedStoryState())
        let first = engine.midnightWelcome()
        XCTAssertTrue(first?.isFirstTime ?? false)
        XCTAssertEqual(first?.gain, MidnightGuests.affinityGain - 2)
        XCTAssertTrue(engine.state.hasFlag("midnight.opened"))
        let second = engine.midnightWelcome()
        XCTAssertFalse(second?.isFirstTime ?? true)
        XCTAssertEqual(second?.gain, 0)

        let early = TestSupport.engine(state: TestSupport.stockedState([]))
        XCTAssertNil(early.midnightWelcome())
    }

    func testGuestDialogueDataIsWellFormed() {
        XCTAssertGreaterThanOrEqual(MidnightGuests.all.count, 5)
        let ids = MidnightGuests.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        let lineIDs = MidnightGuests.all.flatMap { $0.lines.map(\.id) }
        XCTAssertEqual(Set(lineIDs).count, lineIDs.count, "대화 id 중복")
        for scene in MidnightGuests.all {
            XCTAssertGreaterThanOrEqual(scene.lines.count, 3, scene.title)
            XCTAssertFalse(scene.closingThought.isEmpty, scene.title)
        }
        XCTAssertEqual(MidnightGuests.firstScene(for: .dallae)?.id, "midnight.dallae.first")
        XCTAssertEqual(MidnightGuests.closeScene(for: .moru)?.id, "midnight.moru.close")
    }

    func testAffinityDialogueCoversEveryCharacterAndLevel() {
        let lines = AffinityDialogue.allLines()
        XCTAssertEqual(lines.count, CharacterID.allCases.count * AffinityLevel.allCases.count)
        for (character, level, line) in lines {
            XCTAssertFalse(line.isEmpty, "\(character.name) \(level.title)")
        }
        // 같은 이웃이라도 단계가 다르면 다른 말을 한다.
        for character in CharacterID.allCases {
            let texts = AffinityLevel.allCases.map { AffinityDialogue.line(for: character, level: $0) }
            XCTAssertEqual(Set(texts).count, texts.count, character.name)
        }
        let engine = TestSupport.engine(state: completedStoryState())
        XCTAssertEqual(
            engine.affinityLine(for: .tori),
            AffinityDialogue.line(for: .tori, level: .shy)
        )
        var state = completedStoryState()
        state.addAffinity(AffinityLevel.family.rawValue, to: .tori)
        let close = TestSupport.engine(state: state)
        XCTAssertEqual(close.affinityLine(for: .tori), AffinityDialogue.line(for: .tori, level: .family))
    }

    // MARK: - 특별 의뢰

    func testSpecialRequestBookIsWellFormed() {
        XCTAssertEqual(SpecialRequestBook.all.count, 5)
        let ids = SpecialRequestBook.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for request in SpecialRequestBook.all {
            XCTAssertNotNil(RecipeBook.recipe(id: request.recipeID), request.title)
            XCTAssertFalse(request.note.isEmpty, request.title)
            XCTAssertFalse(request.thanks.isEmpty, request.title)
            XCTAssertFalse(request.reward.isEmpty, request.title)
            XCTAssertTrue(Ingredient.allCases.contains { $0 == request.reward[0].ingredient })
        }
    }

    func testRequestNeedsConditionsBeforeDelivery() {
        let request = SpecialRequestBook.request(id: SpecialRequestBook.dawnSongID)
        XCTAssertNotNil(request)
        // 이야기를 마치지 않으면 열리지 않는다.
        var early = TestSupport.stockedState([ItemStack(.nightBellFlower, 2), ItemStack(.mothDustSugar, 2)])
        early.addCooked(recipeID: MidnightRecipes.bellCottonID, quality: .good)
        early.addAffinity(AffinityLevel.close.rawValue, to: .dallae)
        let earlyEngine = TestSupport.engine(state: early)
        XCTAssertFalse(earlyEngine.isRequestUnlocked(SpecialRequestBook.all[0]))
        XCTAssertTrue(earlyEngine.availableRequests.isEmpty)
        XCTAssertFalse(earlyEngine.deliverRequest(SpecialRequestBook.dawnSongID).succeeded)
    }

    func testDeliveringARequestRewardsAndClosesIt() {
        var state = completedStoryState([
            ItemStack(.nightBellFlower, 3),
            ItemStack(.mothDustSugar, 3)
        ])
        state.addAffinity(AffinityLevel.greeting.rawValue, to: .dallae)
        state.addCooked(recipeID: MidnightRecipes.bellCottonID, quality: .good)
        let engine = TestSupport.engine(state: state)

        XCTAssertTrue(engine.availableRequests.contains { $0.id == SpecialRequestBook.dawnSongID })
        let outcome = engine.deliverRequest(SpecialRequestBook.dawnSongID)
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.request?.id, SpecialRequestBook.dawnSongID)
        XCTAssertGreaterThan(outcome.affinityGain, 0)
        XCTAssertTrue(engine.state.hasCompletedRequest(SpecialRequestBook.dawnSongID))
        XCTAssertEqual(engine.state.servings(of: MidnightRecipes.bellCottonID), 0, "잼 한 접시를 건넨다")
        XCTAssertGreaterThan(engine.state.count(of: .nightBellFlower), 1, "보상 재료가 들어온다")
        XCTAssertGreaterThan(engine.state.fireflyDust, 0)

        let again = engine.deliverRequest(SpecialRequestBook.dawnSongID)
        XCTAssertFalse(again.succeeded, "마친 의뢰는 다시 낼 수 없다")
        XCTAssertFalse(engine.availableRequests.contains { $0.id == SpecialRequestBook.dawnSongID })
    }

    // MARK: - 도감 마스터리

    func testCodexMasteryTiersOpenByRecipeCount() {
        XCTAssertEqual(CodexMastery.all.count, 4)
        let thresholds = CodexMastery.all.map(\.recipeCount)
        XCTAssertEqual(thresholds, thresholds.sorted(), "문턱은 오름차순")
        XCTAssertEqual(CodexMastery.unlockedTiers(forRecipeCount: 0).count, 0)
        XCTAssertEqual(CodexMastery.unlockedTiers(forRecipeCount: 8).count, 1)
        XCTAssertEqual(CodexMastery.unlockedTiers(forRecipeCount: 25).count, 3)
        XCTAssertEqual(CodexMastery.unlockedTiers(forRecipeCount: 26).count, 4)
        XCTAssertNil(CodexMastery.nextTier(forRecipeCount: 26))
    }

    func testCodexMasteryRewardIsGivenOnce() {
        var state = completedStoryState()
        for recipe in RecipeBook.all.prefix(8) {
            state.addCooked(recipeID: recipe.id, quality: .good)
        }
        let engine = TestSupport.engine(state: state)
        let first = engine.claimCodexMasteryTiers()
        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(engine.state.hasClaimedCodexTier(first[0].id))
        let dust = engine.state.fireflyDust
        XCTAssertEqual(engine.claimCodexMasteryTiers().count, 0, "보상은 한 번만")
        XCTAssertEqual(engine.state.fireflyDust, dust)
    }

    // MARK: - 저장 호환

    func testExpansionStateSurvivesSaveAndRestore() {
        var state = completedStoryState()
        state.completeRequest(SpecialRequestBook.bridgeFarewellID)
        state.claimCodexTier("codex.apprentice")
        let store = InMemorySaveStore()
        let engine = GameEngine(saveStore: store, state: state)
        engine.saveNow()

        let reopened = GameEngine(saveStore: store)
        XCTAssertTrue(reopened.loadGame())
        XCTAssertTrue(reopened.state.hasCompletedRequest(SpecialRequestBook.bridgeFarewellID))
        XCTAssertTrue(reopened.state.hasClaimedCodexTier("codex.apprentice"))
        XCTAssertTrue(reopened.state.isStoryComplete)
    }
}
