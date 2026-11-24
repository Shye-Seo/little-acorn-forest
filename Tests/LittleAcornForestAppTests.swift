import XCTest
import AcornForestCore
@testable import LittleAcornForest

final class LittleAcornForestAppTests: XCTestCase {
    func testHeartsReflectAffinityLevel() {
        XCTAssertEqual(AppText.hearts(for: .shy), "♡♡♡")
        XCTAssertEqual(AppText.hearts(for: .greeting), "♥♡♡")
        XCTAssertEqual(AppText.hearts(for: .close), "♥♥♡")
        XCTAssertEqual(AppText.hearts(for: .family), "♥♥♥")
    }

    func testTimerFormatting() {
        XCTAssertEqual(AppText.timer(0), "00:00")
        XCTAssertEqual(AppText.timer(7), "00:07")
        XCTAssertEqual(AppText.timer(26), "00:26")
        XCTAssertEqual(AppText.timer(125), "02:05")
        XCTAssertEqual(AppText.timer(-3), "00:00")
    }

    func testPercentClampsToRange() {
        XCTAssertEqual(AppText.percent(0), "0%")
        XCTAssertEqual(AppText.percent(0.456), "46%")
        XCTAssertEqual(AppText.percent(1.4), "100%")
        XCTAssertEqual(AppText.percent(-0.2), "0%")
    }

    func testChapterAndStatusLabels() {
        XCTAssertEqual(AppText.chapterLine(.chapterOne, status: .available), "1장 · 새 이야기")
        XCTAssertEqual(AppText.chapterLine(.epilogue, status: .completed), "에필로그 · 완료")
        XCTAssertEqual(AppText.statusLabel(.locked), "잠김")
    }

    func testStockLine() {
        XCTAssertEqual(AppText.stockLine(ItemStack(.moonflakeSpice, 3)), "🌙 달조각 향신료 3")
    }

    @MainActor
    func testStoreStartsOnTitleThenOpensMap() {
        let store = GameStore(engine: GameEngine(saveStore: InMemorySaveStore()))
        XCTAssertEqual(store.screen, .title)
        XCTAssertFalse(store.hasSave)

        store.newGame()

        XCTAssertEqual(store.screen, .map)
        XCTAssertEqual(store.state.count(of: .dewberry), 2)
        XCTAssertTrue(store.hasSave)
    }

    @MainActor
    func testStartingStoryShowsFirstBeat() {
        let store = GameStore(engine: GameEngine(saveStore: InMemorySaveStore()))
        store.newGame()
        store.startOrResumeStory()

        XCTAssertEqual(store.screen, .story)
        XCTAssertEqual(store.storyStep?.beat?.chapter, .prologue)
        XCTAssertEqual(store.storyStep?.beat?.lineIndex, 0)
    }

    @MainActor
    func testDiaryReturnsToPreviousScreen() {
        let store = GameStore(engine: GameEngine(saveStore: InMemorySaveStore()))
        store.newGame()
        store.openDiary(from: .map)
        XCTAssertEqual(store.screen, .diary)
        store.closeDiary()
        XCTAssertEqual(store.screen, .map)
    }
}

// MARK: - 확장 기능(달·선반·우체통·집중·상점)

extension LittleAcornForestAppTests {
    @MainActor
    private func engine(moon: MoonPhase = .waning) -> GameEngine {
        let engine = GameEngine(saveStore: InMemorySaveStore())
        engine.moonClock = MoonClock(overridePhase: moon)
        return engine
    }

    @MainActor
    func testMoonBadgeTextComesFromEngine() {
        let store = GameStore(engine: engine(moon: .fullMoon))
        XCTAssertEqual(store.moonPhase, .fullMoon)
        XCTAssertTrue(store.moonBadgeLine.contains("보름달"))
        XCTAssertTrue(store.moonDetailLine.contains("비밀 정원"))
        store.cycleMoonOverride()
        XCTAssertNotEqual(store.moonPhase, .fullMoon, "길게 누르면 위상이 바뀐다")
    }

    @MainActor
    func testNewScreensOpenAndReturnToPrevious() {
        let store = GameStore(engine: engine())
        store.newGame()
        store.openShelf()
        XCTAssertEqual(store.screen, .shelf)
        store.back()
        XCTAssertEqual(store.screen, .map)

        store.openMailbox()
        XCTAssertEqual(store.screen, .mailbox)
        store.openFocus()
        XCTAssertEqual(store.screen, .focus)
        store.openStore()
        XCTAssertEqual(store.screen, .store)
        store.back()
        XCTAssertEqual(store.screen, .map)
    }

    @MainActor
    func testDecoratingAJarFillsTheShelf() {
        var state = GameEngine.freshState()
        state.addCooked(recipeID: "dawn-dew-jam", quality: .perfect)
        let store = GameStore(engine: GameEngine(saveStore: InMemorySaveStore(), state: state))
        XCTAssertEqual(store.shelfJars.count, 0)
        let placed = store.decorateJar(recipeID: "dawn-dew-jam",
                                       bottle: .roundGlass,
                                       cap: .cork,
                                       ribbon: .sage,
                                       label: "첫 병")
        XCTAssertTrue(placed)
        XCTAssertEqual(store.shelfJars.count, 1)
        XCTAssertEqual(store.shelfJars.first?.label, "첫 병")
    }

    @MainActor
    func testMailBadgeCountsUnclaimedLetters() {
        var state = GameEngine.freshState()
        let letter = MailboxLetter(sender: .tori, day: 1, gift: ItemStack(.dewberry, 1), note: "안부")
        state.mailbox.append(letter)
        let store = GameStore(engine: GameEngine(saveStore: InMemorySaveStore(), state: state))
        XCTAssertEqual(store.mailBadgeCount, 1)
        store.claimLetter(id: letter.id)
        XCTAssertEqual(store.mailBadgeCount, 0)
    }

    @MainActor
    func testFocusTimerFlowGivesReward() {
        let store = GameStore(engine: engine())
        store.startFocus(.five, track: .rain)
        XCTAssertNotNil(store.focusSession)
        store.tickFocus(300)
        store.finishFocus()
        XCTAssertNil(store.focusSession)
        XCTAssertNotNil(store.lastReward)
        XCTAssertEqual(store.fireflyDust, 1)
    }

    @MainActor
    func testSimulatedPurchaseOpensContent() async {
        let store = GameStore(engine: engine())
        store.purchases.isSimulated = true
        await store.buy(.greenhouse)
        XCTAssertTrue(store.ownsGreenhouse)
        XCTAssertEqual(store.visibleCharacters.count, 6)
        store.purchases.clearSimulation()
    }
}

// MARK: - 밸런스·마무리 불 조절·주문서

extension LittleAcornForestAppTests {
    @MainActor
    private func stockedEngine(_ stacks: [ItemStack]) -> GameEngine {
        var state = GameEngine.freshState()
        state.inventory = stacks
        let engine = GameEngine(saveStore: InMemorySaveStore(), state: state)
        engine.moonClock = MoonClock(overridePhase: .waning)
        return engine
    }

    @MainActor
    func testStoreShowsEnergyAndBlocksWhenEmpty() {
        let store = GameStore(engine: stockedEngine([ItemStack(.dewberry, 2)]))
        XCTAssertEqual(store.moonlightEnergy, GatherBalance.maxEnergy)
        XCTAssertTrue(store.energyStars.hasPrefix("●"))
        for index in 0..<GatherBalance.maxEnergy {
            store.openGathering(at: .cabinKitchen)
            XCTAssertEqual(store.screen, .gathering, "\(index)번째 채집")
            _ = store.collectGathering()
            store.leaveGathering()
        }
        XCTAssertEqual(store.moonlightEnergy, 0)
        store.openGathering(at: .cabinKitchen)
        XCTAssertEqual(store.screen, .map, "기운이 없으면 채집 화면으로 들어가지 않는다")
    }

    @MainActor
    func testGiftHintReadsTheDailyCount() {
        var state = GameEngine.freshState()
        state.addCooked(recipeID: "meteor-berry-compote", quality: .perfect, extraServings: 3)
        let store = GameStore(engine: GameEngine(saveStore: InMemorySaveStore(), state: state))
        XCTAssertTrue(store.giftHint(for: .tori).contains("첫 잼"))
        store.gift(recipeID: "meteor-berry-compote", to: .tori)
        XCTAssertTrue(store.giftHint(for: .tori).contains("60%"), store.giftHint(for: .tori))
    }

    @MainActor
    func testSimmerRunsThroughTheStore() {
        let store = GameStore(engine: stockedEngine([
            ItemStack(.dewberry, 3),
            ItemStack(.starMossShroom, 3)
        ]))
        store.openCooking()
        XCTAssertEqual(store.screen, .cooking)
        XCTAssertTrue(store.startCooking(ingredients: [.dewberry, .starMossShroom]))
        store.tickCooking(10)
        XCTAssertTrue(store.simmerReady)
        store.startSimmer()
        XCTAssertNotNil(store.simmer)
        let request = store.simmer?.currentRequest
        XCTAssertNotNil(request)
        store.tickSimmer(SimmerMinigame.duration + 1)
        store.finishSimmer()
        XCTAssertNotNil(store.lastSimmer)
        XCTAssertNil(store.simmer)
        store.finishCooking()
        XCTAssertNotNil(store.lastCooking)
        XCTAssertEqual(store.screen, .cooking)
    }

    @MainActor
    func testOrderBoardScreenOpensWhenUnlocked() {
        var state = GameEngine.freshState()
        for chapter in [StoryChapter.prologue, .chapterOne, .chapterTwo, .chapterThree] {
            state.markCompleted(chapter)
        }
        for character in CharacterID.coreNeighbours {
            state.addAffinity(AffinityLevel.greeting.rawValue, to: character)
        }
        for recipe in RecipeBook.base {
            state.addCooked(recipeID: recipe.id, quality: .good, extraServings: 5)
        }
        let store = GameStore(engine: GameEngine(saveStore: InMemorySaveStore(), state: state))
        XCTAssertTrue(store.orderBoardUnlocked)
        store.newGame()
        store.openOrders()
        XCTAssertEqual(store.screen, .orders)
        store.back()
        XCTAssertEqual(store.screen, .map)
    }

    @MainActor
    func testDeliveringAnOrderUpdatesTheStore() {
        var state = GameEngine.freshState()
        for chapter in [StoryChapter.prologue, .chapterOne, .chapterTwo, .chapterThree] {
            state.markCompleted(chapter)
        }
        for character in CharacterID.coreNeighbours {
            state.addAffinity(AffinityLevel.greeting.rawValue, to: character)
        }
        for recipe in RecipeBook.base {
            state.addCooked(recipeID: recipe.id, quality: .good, extraServings: 5)
        }
        let engine = GameEngine(saveStore: InMemorySaveStore(), state: state)
        let store = GameStore(engine: engine)
        guard let order = store.todaysOrder else { return XCTFail("주문이 없다") }
        guard let recipe = DailyOrderBoard.matchingRecipes(for: order, in: state).first else {
            return XCTFail("맞는 잼이 없다")
        }
        store.deliverOrder(recipeID: recipe.id)
        XCTAssertNotNil(store.todaysOrderRecord)
        XCTAssertTrue(store.orderPoints > 0)
        XCTAssertEqual(store.orderTitle, .apprentice)
    }
}
