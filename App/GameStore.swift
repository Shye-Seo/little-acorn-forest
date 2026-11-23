import SwiftUI
import AcornForestCore

/// 화면과 엔진 사이의 얇은 다리. 화면은 이 객체만 보면 된다.
@MainActor
final class GameStore: ObservableObject {
    enum Screen: Equatable {
        case title
        case map
        case story
        case gathering
        case cooking
        case diary
        case neighbours
    }

    @Published private(set) var screen: Screen = .title
    @Published private(set) var revision: Int = 0
    @Published var toast: String?
    @Published private(set) var storyStep: StoryStep?
    @Published private(set) var sceneSummary: SceneSummary?
    @Published private(set) var completion: ChapterCompletion?
    @Published private(set) var lastCooking: CookingOutcome?
    @Published private(set) var lastGathering: GatheringSummary?
    @Published private(set) var lastGift: GiftOutcome?

    let engine: GameEngine

    private var toastTask: Task<Void, Never>?
    private var diaryReturn: Screen = .title

    init(engine: GameEngine? = nil) {
        if let engine {
            self.engine = engine
        } else {
            let saveStore = UserDefaultsSaveStore()
            let fresh = GameEngine(saveStore: saveStore)
            _ = fresh.loadGame()
            self.engine = fresh
        }
    }

    // MARK: - 읽기

    var state: GameState { engine.state }
    var hasSave: Bool { engine.hasSave }
    var revisionValue: Int { revision }
    var gathering: GatheringSession? { engine.gathering }
    var cooking: CookingSession? { engine.cooking }

    var storyChoices: [StoryChoice] { storyStep?.choices ?? [] }

    var isAwaitingChoice: Bool {
        guard let storyStep else { return false }
        if case .choice = storyStep { return true }
        return false
    }

    func isLocationUnlocked(_ location: ForestLocation) -> Bool {
        engine.isLocationUnlocked(location)
    }

    var chapterTitle: String {
        engine.currentChapter?.title ?? "도토리 숲의 작은 이야기"
    }

    var chapterSubtitle: String {
        engine.currentChapter?.subtitle ?? "이야기가 모두 끝났어요"
    }

    var progressLine: String { engine.progressLine }
    var nextGoalLine: String { engine.nextGoalLine }

    var completionRatio: Double {
        Double(state.completedChapters.count) / Double(StoryChapter.allCases.count)
    }

    var diaryEntriesUnlocked: Int { state.diary.count }

    var canContinueStory: Bool {
        engine.state.storyPosition != nil || engine.nextChapterToPlay != nil
    }

    var storyButtonTitle: String {
        if engine.state.storyPosition != nil { return "이야기 이어하기" }
        if let chapter = engine.nextChapterToPlay { return "\(chapter.shortTitle) 시작하기" }
        return "이야기 완결"
    }

    private func bump() {
        revision &+= 1
    }

    // MARK: - 화면 이동

    func goToTitle() {
        if screen == .story { engine.pauseStory() }
        storyStep = nil
        sceneSummary = nil
        completion = nil
        screen = .title
        bump()
    }

    func newGame() {
        engine.startNewGame()
        storyStep = nil
        sceneSummary = nil
        completion = nil
        screen = .map
        bump()
    }

    func continueGame() {
        if engine.loadGame() {
            screen = .map
            showToast("이야기를 이어 갑니다.")
        } else {
            showToast(engine.lastMessage.isEmpty ? "저장된 이야기를 불러오지 못했어요." : engine.lastMessage)
            screen = .title
        }
        bump()
    }

    func openMap() {
        if screen == .story { engine.pauseStory() }
        storyStep = nil
        sceneSummary = nil
        completion = nil
        screen = .map
        refreshChapterAvailability()
        bump()
    }

    /// 채집·요리·선물로 조건이 채워졌으면 잠겨 있던 장을 연다.
    func refreshChapterAvailability() {
        if let chapter = engine.refreshChapterAvailability() {
            showToast("\(chapter.shortTitle)이(가) 열렸어요. 숲 지도에서 이어서 걸어가 보세요.")
        }
    }

    func openDiary(from screen: Screen? = nil) {
        diaryReturn = screen ?? self.screen
        self.screen = .diary
        bump()
    }

    func closeDiary() {
        screen = diaryReturn == .diary ? .title : diaryReturn
        bump()
    }

    func openNeighbours() {
        screen = .neighbours
        bump()
    }

    // MARK: - 이야기

    func startOrResumeStory() {
        let step: StoryStep
        if engine.state.storyPosition != nil {
            step = engine.resumeStory()
        } else if let chapter = engine.nextChapterToPlay {
            step = engine.startChapter(chapter)
        } else {
            showToast("이야기가 모두 끝났어요. 숲 일기장을 펼쳐 보세요.")
            return
        }
        screen = .story
        apply(step)
    }

    func advanceStory() {
        guard screen == .story else { return }
        let step = engine.advanceStory()
        apply(step)
    }

    func chooseStoryOption(at index: Int) {
        let step = engine.chooseOption(at: index)
        Haptics.tap()
        apply(step)
    }

    private func apply(_ step: StoryStep) {
        storyStep = step
        sceneSummary = nil
        completion = nil
        switch step {
        case .blocked(let message):
            storyStep = nil
            screen = .map
            showToast(message)
        case .sceneFinished(let summary):
            sceneSummary = summary
        case .completed(let done):
            completion = done
            Haptics.success()
        case .line, .choice:
            break
        }
        bump()
    }

    func continueAfterScene() {
        sceneSummary = nil
        storyStep = engine.currentStep()
        bump()
    }

    func closeCompletion() {
        completion = nil
        storyStep = nil
        sceneSummary = nil
        screen = .map
        bump()
    }

    func leaveStory() {
        engine.pauseStory()
        storyStep = nil
        sceneSummary = nil
        completion = nil
        screen = .map
        bump()
    }

    // MARK: - 채집

    func openGathering(at location: ForestLocation) {
        guard engine.isLocationUnlocked(location) else {
            showToast("\(location.title)은 아직 열리지 않았어요. 이야기를 더 진행해 주세요.")
            return
        }
        if engine.startGathering(at: location) {
            lastGathering = nil
            screen = .gathering
            bump()
        } else {
            showToast(engine.lastMessage)
        }
    }

    func tickGathering(_ delta: Double) {
        guard engine.gathering != nil else { return }
        engine.tickGathering(delta)
        bump()
    }

    func tapLane(_ lane: Int) {
        let result = engine.tapGathering(lane: lane)
        if case .caught = result {
            Haptics.tap()
        }
        bump()
    }

    func collectGathering() -> GatheringSummary? {
        let summary = engine.finishGathering()
        lastGathering = summary
        if let summary, summary.caughtCount > 0 {
            Haptics.success()
        }
        bump()
        return summary
    }

    func leaveGathering() {
        if engine.gathering != nil {
            _ = engine.finishGathering()
        }
        lastGathering = nil
        screen = .map
        bump()
    }

    // MARK: - 요리

    func openCooking() {
        engine.cancelCooking()
        lastCooking = nil
        screen = .cooking
        bump()
    }

    @discardableResult
    func startCooking(ingredients: [Ingredient]) -> Bool {
        let started = engine.startCooking(ingredients: ingredients)
        if !started {
            showToast(engine.lastMessage)
        }
        lastCooking = nil
        bump()
        return started
    }

    func tickCooking(_ delta: Double) {
        guard engine.cooking != nil else { return }
        engine.tickCooking(delta)
        bump()
    }

    func stirCooking() {
        guard engine.cooking != nil else { return }
        engine.stirCooking()
        Haptics.tap()
        bump()
    }

    func finishCooking() {
        lastCooking = engine.finishCooking()
        if lastCooking?.recipe != nil { Haptics.success() } else { Haptics.warning() }
        bump()
    }

    func closeCooking() {
        engine.cancelCooking()
        lastCooking = nil
        screen = .map
        bump()
    }

    // MARK: - 선물

    func gift(recipeID: String, to character: CharacterID) {
        let outcome = engine.gift(recipeID: recipeID, to: character)
        lastGift = outcome
        if outcome.succeeded { Haptics.success() } else { Haptics.warning() }
        showToast(outcome.message)
        bump()
    }

    func giftableRecipes() -> [CookedRecord] {
        state.cooked.filter { $0.servings > 0 }
    }

    // MARK: - 저장

    func saveNow() {
        if engine.saveNow() {
            showToast("저장했어요.")
        }
    }

    func deleteSave() {
        engine.deleteSave()
        storyStep = nil
        sceneSummary = nil
        completion = nil
        screen = .title
        bump()
    }

    // MARK: - 토스트

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
