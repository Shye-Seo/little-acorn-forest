import XCTest
import AcornForestCore

final class SaveRestoreTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_760_000_000)

    func testCodecRoundTripKeepsState() throws {
        var state = GameState(startedAt: fixedDate)
        state.add(.moonHerb, count: 3)
        state.addAffinity(30, to: .rubi)
        state.addCooked(recipeID: "raspberry-jam", quality: .perfect)
        state.unlockDiary("recipe.raspberry-jam")
        state.setFlag("test")
        state.markCompleted(.prologue)
        state.setStatus(.available, for: .chapterOne)
        let file = SaveFile(state: state, savedAt: fixedDate)

        let data = try SaveCodec.encode(file)
        let restored = try SaveCodec.decode(data)

        XCTAssertEqual(restored.state, state)
        XCTAssertEqual(restored.savedAt, fixedDate)
        XCTAssertEqual(restored.formatVersion, GameState.currentFormatVersion)
    }

    func testDecodingGarbageThrowsCorrupted() {
        let data = Data("이건 저장 파일이 아니다".utf8)
        XCTAssertThrowsError(try SaveCodec.decode(data)) { error in
            XCTAssertEqual(error as? SaveError, .corrupted)
        }
    }

    func testEngineAutosavesOnNewGame() {
        let store = InMemorySaveStore()
        let engine = GameEngine(saveStore: store)
        XCTAssertFalse(engine.hasSave)
        engine.startNewGame()
        XCTAssertTrue(engine.hasSave)
        XCTAssertEqual(store.saveCount, 1)
        XCTAssertNotNil(engine.lastSavedAt)
    }

    func testSecondEngineRestoresProgress() {
        let store = InMemorySaveStore()
        let first = GameEngine(saveStore: store)
        first.startNewGame()
        XCTAssertTrue(first.startGathering(at: .berryPatch, seed: 21))
        TestSupport.catchEverything(first)
        _ = TestSupport.playChapter(first, .prologue)

        let second = GameEngine(saveStore: store)
        XCTAssertTrue(second.loadGame())
        XCTAssertEqual(second.state.completedChapters, first.state.completedChapters)
        XCTAssertEqual(second.state.totalIngredients, first.state.totalIngredients)
        XCTAssertEqual(second.state.stats.totalCaught, first.state.stats.totalCaught)
        XCTAssertEqual(second.status(of: .chapterOne), .available)
    }

    func testLoadWithoutSaveFails() {
        let engine = GameEngine(saveStore: InMemorySaveStore())
        XCTAssertFalse(engine.loadGame())
        XCTAssertEqual(engine.state.completedChapters, [])
    }

    func testDeleteClearsSaveAndResetsState() {
        let store = InMemorySaveStore()
        let engine = GameEngine(saveStore: store)
        engine.startNewGame()
        _ = TestSupport.playChapter(engine, .prologue)
        XCTAssertTrue(engine.state.hasDiary("chapter.prologue"))
        engine.deleteSave()
        XCTAssertFalse(engine.hasSave)
        XCTAssertEqual(engine.state.completedChapters, [])
        XCTAssertFalse(engine.state.hasDiary("chapter.prologue"))
        XCTAssertEqual(store.deleteCount, 1)
    }

    func testNormalizeFillsMissingFields() {
        var state = GameState()
        state.chapters = []
        state.affinity = []
        state.inventory = [ItemStack(.acorn, 0), ItemStack(.raspberry, 2)]
        state.diary = ["chapter.prologue", "chapter.prologue"]
        state.normalize()
        XCTAssertEqual(state.chapters.count, StoryChapter.allCases.count)
        XCTAssertEqual(state.affinity.count, CharacterID.allCases.count)
        XCTAssertEqual(state.inventory.count, 1)
        XCTAssertEqual(state.diary, ["chapter.prologue"])
        XCTAssertEqual(state.formatVersion, GameState.currentFormatVersion)
    }

    func testUnsavedStoryPositionIsPreserved() {
        let store = InMemorySaveStore()
        let engine = GameEngine(saveStore: store)
        engine.startNewGame()
        _ = engine.startChapter(.prologue)
        _ = engine.advanceStory()

        let reopened = GameEngine(saveStore: store)
        XCTAssertTrue(reopened.loadGame())
        let step = reopened.resumeStory()
        XCTAssertNotNil(step.beat)
        XCTAssertEqual(step.beat?.lineIndex, 1)
    }
}
