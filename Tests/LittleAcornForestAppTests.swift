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
