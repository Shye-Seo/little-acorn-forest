import XCTest
import AcornForestCore

final class ChapterProgressTests: XCTestCase {
    func testNewGameStartsWithPrologueOnly() {
        let engine = TestSupport.engine()
        XCTAssertEqual(engine.status(of: .prologue), .available)
        XCTAssertEqual(engine.status(of: .chapterOne), .locked)
        XCTAssertEqual(engine.status(of: .chapterTwo), .locked)
        XCTAssertEqual(engine.status(of: .chapterThree), .locked)
        XCTAssertEqual(engine.status(of: .epilogue), .locked)
        XCTAssertEqual(engine.state.count(of: .dewberry), 2)
        XCTAssertEqual(engine.state.count(of: .fireflyNectar), 1)
    }

    func testPlayingPrologueUnlocksChapterOne() {
        let engine = TestSupport.engine()
        let step = TestSupport.playChapter(engine, .prologue)
        guard case .completed(let completion) = step else {
            return XCTFail("프롤로그가 끝나지 않았다: \(step)")
        }
        XCTAssertEqual(completion.chapter, .prologue)
        XCTAssertEqual(engine.status(of: .prologue), .completed)
        XCTAssertEqual(engine.status(of: .chapterOne), .available)
        XCTAssertEqual(engine.state.storyPosition, nil)
        XCTAssertTrue(engine.state.hasDiary("chapter.prologue"))
        XCTAssertGreaterThan(engine.state.count(of: .dewberry), 0)
    }

    func testChoiceGivesAffinityOnce() {
        let engine = TestSupport.engine()
        _ = TestSupport.playChapter(engine, .prologue, choiceIndex: 0)
        let points = engine.state.affinityPoints(for: .tori)
        XCTAssertEqual(points, 4)
        XCTAssertTrue(engine.state.hasFlag("prologue.warmFirst"))
    }

    func testChapterTwoNeedsGatheringAndCooking() {
        let engine = TestSupport.engine(state: TestSupport.stateWithPrologueDone())
        _ = TestSupport.playChapter(engine, .chapterOne)
        XCTAssertEqual(engine.status(of: .chapterOne), .completed)
        XCTAssertEqual(engine.status(of: .chapterTwo), .locked, "채집과 요리 없이는 2장이 열리면 안 된다")

        XCTAssertTrue(engine.startGathering(at: .berryPatch, seed: 21))
        TestSupport.catchEverything(engine)
        XCTAssertTrue(engine.startCooking(ingredients: [.dewberry, .fireflyNectar]))
        TestSupport.stirToPerfect(engine)
        _ = engine.finishCooking()

        XCTAssertTrue(ChapterRules.isUnlocked(.chapterTwo, in: engine.state))
        XCTAssertEqual(engine.status(of: .chapterTwo), .locked, "상태 갱신은 지도 화면에서 일어난다")
    }

    func testChapterThreeNeedsGreetingsAndThreeRecipes() {
        var state = TestSupport.stateWithPrologueDone()
        state.markCompleted(.chapterOne)
        state.markCompleted(.chapterTwo)
        state.stats.totalCaught = 10
        state.addCooked(recipeID: "dawn-dew-jam", quality: .good)
        state.addCooked(recipeID: "firefly-sparkle-jam", quality: .good)
        state.addCooked(recipeID: "starlight-mist-jam", quality: .good)
        XCTAssertFalse(ChapterRules.isUnlocked(.chapterThree, in: state))

        for character in CharacterID.allCases {
            state.addAffinity(20, to: character)
        }
        XCTAssertTrue(ChapterRules.isUnlocked(.chapterThree, in: state))
    }

    func testEpilogueNeedsCakeAndCloseFriends() {
        var state = TestSupport.stateWithPrologueDone()
        state.markCompleted(.chapterOne)
        state.markCompleted(.chapterTwo)
        state.markCompleted(.chapterThree)
        XCTAssertFalse(ChapterRules.isUnlocked(.epilogue, in: state))

        state.addCooked(recipeID: "golden-fullmoon-jam", quality: .perfect)
        for character in CharacterID.allCases {
            state.addAffinity(45, to: character)
        }
        XCTAssertTrue(ChapterRules.isUnlocked(.epilogue, in: state))
    }

    func testGoalsHaveReadableProgressText() {
        var progressed = TestSupport.stockedState([])
        progressed.markCompleted(.prologue)
        progressed.markCompleted(.chapterOne)
        progressed.setStatus(.available, for: .chapterTwo)
        let engine = TestSupport.engine(state: progressed)
        let goals = engine.goals(for: .chapterTwo)
        XCTAssertEqual(goals.count, 3)
        XCTAssertTrue(goals.contains { $0.isMet }, "이미 끝난 1장 조건은 충족으로 보여야 한다")
        XCTAssertTrue(goals.allSatisfy { !$0.text.isEmpty })
        XCTAssertTrue(goals.contains { $0.text.contains("0/4") })
    }

    func testRefreshUnlocksChapterAfterGatheringAndCooking() {
        let engine = TestSupport.engine(state: TestSupport.stateWithPrologueDone())
        _ = TestSupport.playChapter(engine, .chapterOne)
        XCTAssertEqual(engine.status(of: .chapterTwo), .locked)

        XCTAssertTrue(engine.startGathering(at: .berryPatch, seed: 21))
        TestSupport.catchEverything(engine)
        XCTAssertTrue(engine.startCooking(ingredients: [.dewberry, .fireflyNectar]))
        _ = engine.finishCooking()

        XCTAssertEqual(engine.refreshChapterAvailability(), .chapterTwo)
        XCTAssertEqual(engine.status(of: .chapterTwo), .available)
        XCTAssertNil(engine.refreshChapterAvailability(), "이미 열린 장을 또 열지는 않는다")
    }

    func testCompletedChapterCannotBeReplayedForRewards() {
        let engine = TestSupport.engine()
        _ = TestSupport.playChapter(engine, .prologue)
        let berries = engine.state.count(of: .dewberry)
        let step = engine.startChapter(.prologue)
        guard case .blocked = step else {
            return XCTFail("이미 끝난 이야기가 다시 시작됐다")
        }
        XCTAssertEqual(engine.state.count(of: .dewberry), berries)
    }

    func testFullStoryCanBeCompleted() {
        var state = TestSupport.stateWithPrologueDone()
        state.markCompleted(.chapterOne)
        state.markCompleted(.chapterTwo)
        for character in CharacterID.allCases {
            state.addAffinity(45, to: character)
        }
        state.addCooked(recipeID: "golden-fullmoon-jam", quality: .perfect)
        state.cooked.append(CookedRecord(recipeID: "dawn-dew-jam", servings: 0, timesCooked: 1))
        state.setStatus(.available, for: .chapterThree)
        state.setStatus(.available, for: .epilogue)
        let engine = TestSupport.engine(state: state)

        let third = TestSupport.playChapter(engine, .chapterThree)
        guard case .completed = third else {
            return XCTFail("3장이 끝나지 않았다: \(third)")
        }
        let epilogue = TestSupport.playChapter(engine, .epilogue)
        guard case .completed = epilogue else {
            return XCTFail("에필로그가 끝나지 않았다: \(epilogue)")
        }
        XCTAssertTrue(engine.isStoryComplete)
        XCTAssertTrue(engine.state.hasDiary(ForestDiary.festivalEntryID))
        XCTAssertEqual(engine.state.completedChapters.count, StoryChapter.allCases.count)
    }

    func testUnlockMessageExplainsMissingGoals() {
        let state = TestSupport.stateWithPrologueDone()
        let message = ChapterRules.unlockMessage(for: .prologue, in: state)
        XCTAssertTrue(message.contains("열렸"), message)

        var bare = GameState()
        bare.setStatus(.inProgress, for: .prologue)
        let locked = ChapterRules.unlockMessage(for: .prologue, in: bare)
        XCTAssertTrue(locked.contains("아직 열리지 않았"), locked)
    }
}
