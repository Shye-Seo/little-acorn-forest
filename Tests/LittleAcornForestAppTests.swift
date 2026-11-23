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
        XCTAssertEqual(AppText.stockLine(ItemStack(.moonHerb, 3)), "🌿 달빛허브 3")
    }

    @MainActor
    func testStoreStartsOnTitleThenOpensMap() {
        let store = GameStore(engine: GameEngine(saveStore: InMemorySaveStore()))
        XCTAssertEqual(store.screen, .title)
        XCTAssertFalse(store.hasSave)

        store.newGame()

        XCTAssertEqual(store.screen, .map)
        XCTAssertEqual(store.state.count(of: .acorn), 2)
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
