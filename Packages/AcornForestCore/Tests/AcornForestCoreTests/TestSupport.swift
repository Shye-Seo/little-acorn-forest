import Foundation
import XCTest
import AcornForestCore

enum TestSupport {
    /// 테스트는 달 위상을 그믐달로 고정한다. 위상 효과가 섞이지 않게 하기 위해서다.
    static let defaultMoon: MoonPhase = .waning
    /// 달 위상 테스트에 쓰는 고정 시각(2026-11-24 15:00 UTC).
    static let fixedDate = Date(timeIntervalSince1970: 1_795_388_400)

    static func engine(state: GameState? = nil, moon: MoonPhase = TestSupport.defaultMoon) -> GameEngine {
        let engine = GameEngine(saveStore: InMemorySaveStore(), state: state)
        engine.moonClock = MoonClock(overridePhase: moon)
        engine.now = { TestSupport.fixedDate }
        return engine
    }

    static func stateWithPrologueDone() -> GameState {
        var state = GameEngine.freshState()
        state.markCompleted(.prologue)
        state.setStatus(.available, for: .chapterOne)
        return state
    }

    static func stockedState(_ stacks: [ItemStack], completed: [StoryChapter] = []) -> GameState {
        var state = GameEngine.freshState()
        state.inventory = stacks
        for chapter in completed {
            state.markCompleted(chapter)
        }
        return state
    }

    /// 이야기를 끝까지 진행한다. 선택지는 지정한 번호를 고른다.
    @discardableResult
    static func playChapter(_ engine: GameEngine, _ chapter: StoryChapter, choiceIndex: Int = 0) -> StoryStep {
        var step = engine.startChapter(chapter)
        var rounds = 0
        while rounds < 500 {
            rounds += 1
            switch step {
            case .line:
                step = engine.advanceStory()
            case .choice:
                step = engine.chooseOption(at: choiceIndex)
            case .sceneFinished:
                step = engine.currentStep()
            case .completed, .blocked:
                return step
            }
        }
        return step
    }

    /// 세션에 등장하는 모든 재료를 도착 시각에 맞춰 담는다.
    static func catchEverything(_ engine: GameEngine) {
        guard let session = engine.gathering else { return }
        let items = session.items.sorted { $0.catchTime < $1.catchTime }
        var clock = 0.0
        for item in items {
            let delta = item.catchTime - clock
            if delta > 0 {
                engine.tickGathering(delta)
                clock = item.catchTime
            }
            _ = engine.tapGathering(lane: item.lane)
        }
        engine.finishGathering()
    }

    /// 불을 은근하게 유지하며 요리를 마친다(완벽한 온기).
    static func stirToPerfect(_ engine: GameEngine) {
        var steps = 0
        while steps < 200 {
            steps += 1
            engine.tickCooking(0.1)
            if engine.cooking == nil { return }
            if let cooking = engine.cooking, cooking.heat > 0.62 {
                engine.stirCooking()
            }
        }
    }
}
