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
        case shelf
        case mailbox
        case focus
        case store
        case greenhouse
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
    @Published private(set) var lastReward: FocusReward?
    @Published private(set) var dialogue: DialogueOutcome?
    @Published private(set) var selectedCharacter: CharacterID?
    @Published private(set) var shelfPreselect: String?

    let engine: GameEngine
    let purchases = StoreManager()

    private var toastTask: Task<Void, Never>?
    private var diaryReturn: Screen = .title
    private var returnScreen: Screen = .map

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

    func lockMessage(for location: ForestLocation) -> String {
        engine.lockMessage(for: location)
    }

    var chapterTitle: String {
        engine.currentChapter?.title ?? "달빛 잼 항아리"
    }

    var chapterSubtitle: String {
        engine.currentChapter?.subtitle ?? "이야기가 모두 끝났어요"
    }

    var progressLine: String { engine.progressLine }
    var nextGoalLine: String { engine.nextGoalLine }

    var completionRatio: Double {
        Double(state.completedChapters.count) / Double(StoryChapter.allCases.count)
    }

    var diaryEntriesUnlocked: Int { state.diaryProgress.unlocked }

    var canContinueStory: Bool {
        engine.state.storyPosition != nil || engine.nextChapterToPlay != nil
    }

    var storyButtonTitle: String {
        if engine.state.storyPosition != nil { return "이야기 이어하기" }
        if let chapter = engine.nextChapterToPlay { return "\(chapter.shortTitle) 시작하기" }
        return "이야기 완결"
    }

    // MARK: - 달

    var moonPhase: MoonPhase { engine.currentMoonPhase }
    var moonBadgeLine: String { engine.moonBadgeLine }
    var moonDetailLine: String {
        if engine.currentMoonPhase.isFullMoon { return "달빛 비밀 정원이 열렸어요" }
        let days = max(1, Int(engine.daysUntilFullMoon.rounded(.up)))
        return "다음 보름달까지 \(days)일"
    }
    var moonGardenLine: String { engine.moonGardenLine }
    var isMoonlitGardenOpen: Bool { engine.isMoonlitGardenOpen }

    /// 달 배지를 길게 누르면 위상을 한 단계씩 고정한다(디버그).
    func cycleMoonOverride() {
        let order = MoonPhase.allCases
        guard let current = engine.state.debugMoonOverride else {
            engine.setMoonOverride(order[0])
            showToast("달을 \(order[0].title)(으)로 고정했어요.")
            bump()
            return
        }
        let nextIndex = (order.firstIndex(of: current) ?? 0) + 1
        if nextIndex >= order.count {
            engine.setMoonOverride(nil)
            showToast("달을 실제 날짜로 되돌렸어요.")
        } else {
            engine.setMoonOverride(order[nextIndex])
            showToast("달을 \(order[nextIndex].title)(으)로 고정했어요.")
        }
        bump()
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
        dialogue = nil
        screen = .map
        refreshChapterAvailability()
        bump()
    }

    /// 채집·잼·선물로 조건이 채워졌으면 잠겨 있던 장을 연다.
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
        returnScreen = screen
        screen = .neighbours
        bump()
    }

    func openShelf(preselect recipeID: String? = nil) {
        returnScreen = screen
        shelfPreselect = recipeID
        screen = .shelf
        bump()
    }

    func openMailbox() {
        returnScreen = screen
        screen = .mailbox
        bump()
    }

    func openFocus() {
        returnScreen = screen
        lastReward = nil
        screen = .focus
        bump()
    }

    func openStore() {
        returnScreen = screen
        screen = .store
        bump()
    }

    func openGreenhouse() {
        guard engine.owns(.greenhouse), engine.isLocationUnlocked(.greenhouse) else {
            showToast(engine.lockMessage(for: .greenhouse))
            return
        }
        returnScreen = .map
        screen = .greenhouse
        bump()
    }

    func back() {
        if screen == .shelf { shelfPreselect = nil }
        if screen == .focus { stopFocusAudio() }
        dialogue = nil
        selectedCharacter = nil
        screen = returnScreen == screen ? .map : returnScreen
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
            showToast(engine.lockMessage(for: location))
            Haptics.warning()
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

    // MARK: - 잼

    func openCooking() {
        engine.cancelCooking()
        lastCooking = nil
        returnScreen = .map
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

    func recipePreview(for ingredients: [Ingredient]) -> Recipe? {
        engine.recipePreview(for: ingredients)
    }

    var visibleIngredients: [Ingredient] { engine.visibleIngredients }

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

    // MARK: - 잼 병과 선반

    var shelfJars: [CustomJamJar] { engine.shelfJars }
    var canDecorate: Bool { engine.canDecorate }
    var ownsWorkshop: Bool { engine.owns(.bottleWorkshop) }
    var cabinStyle: CabinStyle { state.cabinStyle }
    var unlockedCabinStyles: [CabinStyle] { state.unlockedCabinStyles }
    var unlockedBottles: [JarBottleStyle] { state.unlockedBottles }
    var unlockedCaps: [JarCapStyle] { state.unlockedCaps }

    func decorateJar(recipeID: String,
                     bottle: JarBottleStyle,
                     cap: JarCapStyle,
                     ribbon: JarRibbonColor,
                     label: String) -> Bool {
        let outcome = engine.decorateJar(recipeID: recipeID, bottle: bottle, cap: cap, ribbon: ribbon, label: label)
        if outcome.succeeded {
            Haptics.success()
            ForestAudio.shared.playJarPop()
            toast = outcome.message
            shelfPreselect = nil
        } else {
            Haptics.warning()
            showToast(outcome.message)
        }
        bump()
        return outcome.succeeded
    }

    func removeJar(id: String) {
        if engine.removeJar(id: id) {
            Haptics.tap()
            showToast(engine.lastMessage)
        }
        bump()
    }

    func setCabinStyle(_ style: CabinStyle) {
        engine.setCabinStyle(style)
        Haptics.tap()
        bump()
    }

    // MARK: - 우체통

    var mailboxLetters: [MailboxLetter] { engine.sortedLetters }
    var mailBadgeCount: Int { engine.mailBadgeCount }

    func checkMailbox() {
        let delivered = engine.checkMailbox()
        if !delivered.isEmpty {
            Haptics.success()
            showToast("우체통에 편지 \(delivered.count)통이 들어왔어요.")
        } else {
            showToast("새로 온 편지는 없어요.")
        }
        bump()
    }

    func claimLetter(id: String) {
        if let letter = engine.claimLetter(id: id) {
            Haptics.success()
            showToast(engine.lastMessage.isEmpty ? "\(letter.sender.name)의 편지를 읽었어요." : engine.lastMessage)
        }
        bump()
    }

    /// 테스트·디버그용 하루 넘기기.
    func simulateNextDay() {
        let delivered = engine.simulateNextDay()
        showToast(delivered.isEmpty ? "하루가 지났지만 새 편지는 없어요." : "하루가 지났어요. 편지 \(delivered.count)통.")
        bump()
    }

    // MARK: - 집중 타이머

    var focusSession: FocusSession? { engine.focusSession }
    var focusRewardPreview: FocusReward? { engine.currentFocusRewardPreview }
    var fireflyDust: Int { state.fireflyDust }
    var focusSessions: Int { state.focusSessions }
    var unlockedTracks: [AmbientTrack] { state.unlockedTracks }

    func isTrackAvailable(_ track: AmbientTrack) -> Bool {
        engine.isTrackAvailable(track)
    }

    func startFocus(_ duration: FocusDuration, track: AmbientTrack) {
        guard engine.startFocus(duration, track: track) else {
            showToast(engine.lastMessage)
            return
        }
        ForestAudio.shared.playAmbient(track)
        lastReward = nil
        Haptics.tap()
        bump()
    }

    func tickFocus(_ delta: Double) {
        guard engine.focusSession != nil else { return }
        engine.tickFocus(delta)
        bump()
    }

    func finishFocus() {
        if let reward = engine.finishFocus() {
            lastReward = reward
            ForestAudio.shared.stopAmbient()
            Haptics.success()
            showToast(reward.message)
        }
        bump()
    }

    func clearFocusReward() {
        lastReward = nil
        bump()
    }

    func cancelFocus() {
        engine.cancelFocus()
        ForestAudio.shared.stopAmbient()
        lastReward = nil
        bump()
    }

    func stopFocusAudio() {
        ForestAudio.shared.stopAmbient()
    }

    // MARK: - 확장팩과 상점

    var storeProducts: [ContentPack] { StoreCatalog.all }
    var ownsGreenhouse: Bool { engine.owns(.greenhouse) }
    var ownsASMR: Bool { engine.owns(.asmrTracks) }
    var secretRecipeCount: Int { state.secretRecipes.count }

    /// 일기장에 확장 기록 칸을 함께 보여 줄지.
    var showsExpandedDiary: Bool {
        ownsGreenhouse || secretRecipeCount > 0
    }

    var expandedDiaryUnlocked: Int { state.expandedDiaryProgress.unlocked }
    var expandedDiaryTotal: Int { state.expandedDiaryProgress.total }

    func owns(_ pack: ContentPack) -> Bool {
        engine.owns(pack)
    }

    func prepareStore() async {
        await purchases.load()
        applyEntitlements(await purchases.currentEntitlements())
    }

    func buy(_ pack: ContentPack) async {
        purchases.statusMessage = nil
        let purchased = await purchases.purchase(pack)
        if purchased {
            applyEntitlements(await purchases.currentEntitlements())
            showToast("「\(pack.displayName)」이(가) 열렸어요.")
        } else if let message = purchases.statusMessage {
            showToast(message)
        }
        bump()
    }

    func restorePurchases() async {
        let ids = await purchases.restore()
        applyEntitlements(ids)
        showToast(ids.isEmpty ? "복원할 구매가 없어요." : "구매를 복원했어요.")
        bump()
    }

    func toggleSimulation() {
        purchases.isSimulated.toggle()
        showToast(purchases.isSimulated ? "로컬 구매 시뮬레이션을 켰어요." : "실제 StoreKit 결제로 돌아갑니다.")
        bump()
    }

    private func applyEntitlements(_ ids: Set<String>) {
        for id in ids {
            guard let pack = StoreCatalog.pack(forProductID: id) else { continue }
            _ = engine.grantPack(pack)
        }
        bump()
    }

    // MARK: - 온실과 대화

    var visibleCharacters: [CharacterID] { engine.visibleCharacters }

    func openDialogue(with character: CharacterID) {
        if character.isExpansionCharacter {
            guard let outcome = engine.talk(to: character) else {
                showToast(engine.lastMessage)
                return
            }
            dialogue = outcome
            if outcome.gain > 0 { Haptics.success() }
        } else {
            selectedCharacter = character
        }
        bump()
    }

    func openGreenhouseWelcome() {
        if let outcome = engine.greenhouseWelcome() {
            dialogue = outcome
        } else {
            showToast(engine.lastMessage)
        }
        bump()
    }

    func closeDialogue() {
        dialogue = nil
        bump()
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

    private func bump() {
        revision &+= 1
    }
}
