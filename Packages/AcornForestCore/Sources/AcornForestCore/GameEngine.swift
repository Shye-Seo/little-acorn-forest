import Foundation

/// 선물 결과.
public struct GiftOutcome: Sendable, Equatable {
    public let succeeded: Bool
    public let character: CharacterID
    public let recipe: Recipe?
    public let quality: CookingQuality
    public let gain: Int
    public let levelBefore: AffinityLevel
    public let levelAfter: AffinityLevel
    public let unlockedDiary: [String]
    public let message: String
    /// 같은 날 몇 번째 잼인지에 따른 호감도 비율(1.0이면 온전히).
    public let factor: Double

    public init(succeeded: Bool,
                character: CharacterID,
                recipe: Recipe?,
                quality: CookingQuality,
                gain: Int,
                levelBefore: AffinityLevel,
                levelAfter: AffinityLevel,
                unlockedDiary: [String],
                message: String,
                factor: Double = 1) {
        self.succeeded = succeeded
        self.character = character
        self.recipe = recipe
        self.quality = quality
        self.gain = gain
        self.levelBefore = levelBefore
        self.levelAfter = levelAfter
        self.unlockedDiary = unlockedDiary
        self.message = message
        self.factor = factor
    }

    public var didLevelUp: Bool { levelAfter > levelBefore }

    /// 오늘 이미 한 번 나눠 먹어서 반가움이 작았는지.
    public var wasDiminished: Bool { factor < 1 }
}

/// 게임의 두뇌. 화면은 이 객체만 알면 되고, 규칙은 모두 여기에 있다.
/// 모든 변화는 즉시 `SaveStore`로 자동 저장된다.
public final class GameEngine {
    public private(set) var state: GameState
    public private(set) var gathering: GatheringSession?
    public private(set) var cooking: CookingSession?
    public private(set) var simmer: SimmerMinigame?
    public private(set) var simmerResult: SimmerOutcome?
    public private(set) var focus: FocusSession?
    public private(set) var lastSavedAt: Date?
    public private(set) var lastMessage: String = ""

    /// 테스트와 디버그에서 지금 시각을 고정할 때 바꾼다.
    public var now: () -> Date = { Date() }
    /// 테스트에서 달 위상을 고정할 때 바꾼다.
    public var moonClock: MoonClock = MoonClock()

    private let saveStore: SaveStore
    private var pendingReply: StoryLine?

    public init(saveStore: SaveStore, state: GameState? = nil) {
        self.saveStore = saveStore
        self.state = state ?? GameEngine.freshState()
    }

    public static func freshState() -> GameState {
        var fresh = GameState()
        fresh.add(GameState.startingBasket)
        fresh.setStatus(.available, for: .prologue)
        return fresh
    }

    // MARK: - 저장

    public var hasSave: Bool { saveStore.hasSave() }

    public var hasProgress: Bool {
        state.stats.totalCaught > 0
            || state.stats.cooks > 0
            || !state.completedChapters.isEmpty
            || state.storyPosition != nil
            || !state.jars.isEmpty
            || !state.purchasedPacks.isEmpty
            || state.focusSessions > 0
            || !state.orders.isEmpty
    }

    @discardableResult
    public func saveNow() -> Bool {
        let file = SaveFile(state: state)
        do {
            try saveStore.save(file)
            lastSavedAt = file.savedAt
            return true
        } catch {
            lastMessage = "저장하지 못했어요. 기기 저장 공간을 확인해 주세요."
            return false
        }
    }

    @discardableResult
    public func loadGame() -> Bool {
        do {
            guard let file = try saveStore.load() else { return false }
            state = file.state
            state.normalize()
            lastSavedAt = file.savedAt
            pendingReply = nil
            gathering = nil
            cooking = nil
            simmer = nil
            simmerResult = nil
            focus = nil
            lastMessage = "이야기를 이어 갑니다."
            return true
        } catch let error as SaveError {
            lastMessage = error.message
            return false
        } catch {
            lastMessage = SaveError.corrupted.message
            return false
        }
    }

    /// 하루가 바뀌었으면 달빛 기운을 다시 채운다. 화면이 들어올 때마다 불러도 안전하다.
    @discardableResult
    public func refreshDailyState() -> Bool {
        let today = state.currentDay(at: now())
        guard state.beginNewDayIfNeeded(today) else { return false }
        autoSave()
        return true
    }

    public func startNewGame() {
        state = GameEngine.freshState()
        pendingReply = nil
        gathering = nil
        cooking = nil
        simmer = nil
        simmerResult = nil
        focus = nil
        lastMessage = "할머니의 오두막 앞에 도착했어요."
        saveNow()
    }

    public func deleteSave() {
        try? saveStore.delete()
        state = GameEngine.freshState()
        pendingReply = nil
        gathering = nil
        cooking = nil
        simmer = nil
        simmerResult = nil
        focus = nil
        lastSavedAt = nil
        lastMessage = ""
    }

    private func autoSave() {
        saveNow()
    }

    // MARK: - 챕터

    public func status(of chapter: StoryChapter) -> ChapterStatus {
        state.status(of: chapter)
    }

    public func isUnlocked(_ chapter: StoryChapter) -> Bool {
        ChapterRules.isUnlocked(chapter, in: state)
    }

    public var currentChapter: StoryChapter? {
        if let position = state.storyPosition { return position.chapter }
        return ChapterRules.nextPlayableChapter(in: state)
    }

    public func goals(for chapter: StoryChapter) -> [ChapterGoal] {
        ChapterRules.goals(for: chapter, in: state)
    }

    public var nextChapterToPlay: StoryChapter? {
        if let position = state.storyPosition, !position.chapter.isFinal { return position.chapter }
        return ChapterRules.nextPlayableChapter(in: state)
    }

    public var isStoryComplete: Bool { state.isStoryComplete }

    /// 채집·요리·선물 뒤에 "이제 열리는 장이 있는지" 다시 확인한다.
    /// 상태를 바꾼 쪽(엔진)이 아니라 지도 화면이 들어올 때 부르는 용도로도 쓴다.
    @discardableResult
    public func refreshChapterAvailability() -> StoryChapter? {
        guard let chapter = StoryChapter.ordered.first(where: {
            state.status(of: $0) == .locked && ChapterRules.isUnlocked($0, in: state)
        }) else { return nil }
        state.setStatus(.available, for: chapter)
        lastMessage = "\(chapter.shortTitle)이(가) 열렸어요."
        autoSave()
        return chapter
    }

    /// 챕터를 처음부터 시작한다. 이미 열려 있지 않으면 이유를 담아 돌려준다.
    public func startChapter(_ chapter: StoryChapter) -> StoryStep {
        guard !StoryScript.scenes(in: chapter).isEmpty else {
            return .blocked("이 챕터의 대본이 아직 없어요.")
        }
        if state.status(of: chapter) == .completed {
            return .blocked("이미 마친 이야기예요. 숲 일기장에서 다시 읽을 수 있어요.")
        }
        guard ChapterRules.isUnlocked(chapter, in: state) || state.status(of: chapter).isPlayable else {
            let unmet = ChapterRules.goals(for: chapter, in: state).filter { !$0.isMet }.map(\.text)
            return .blocked("아직 열리지 않았어요. " + unmet.joined(separator: " · "))
        }
        state.setStatus(.inProgress, for: chapter)
        state.storyPosition = StoryPosition(chapter: chapter, sceneIndex: 0, lineIndex: 0)
        state.setFlag("chapter.started.\(chapter.rawValue)")
        pendingReply = nil
        autoSave()
        return currentStep()
    }

    /// 저장된 위치에서 이어서.
    public func resumeStory() -> StoryStep {
        guard state.storyPosition != nil else {
            return .blocked("이어 갈 이야기가 없어요. 숲 지도에서 다음 장을 열어 주세요.")
        }
        return currentStep()
    }

    /// 이야기 화면에서 나가기. 챕터는 '진행 중'으로 남는다.
    public func pauseStory() {
        pendingReply = nil
        autoSave()
    }

    public func currentStep() -> StoryStep {
        guard let position = state.storyPosition else {
            return .blocked("이야기가 아직 시작되지 않았어요.")
        }
        guard let scene = StoryScript.scene(chapter: position.chapter, index: position.sceneIndex) else {
            return .blocked("다음 장면을 찾지 못했어요. 숲 지도로 돌아가 주세요.")
        }

        if let reply = pendingReply {
            let beat = StoryBeat(
                sceneID: scene.id,
                sceneTitle: scene.title,
                chapter: scene.chapter,
                line: reply,
                lineIndex: max(0, scene.lines.count - 1),
                lineCount: scene.lines.count,
                isLastLine: true
            )
            return .line(beat)
        }

        guard !scene.lines.isEmpty else {
            return .blocked("장면이 비어 있어요.")
        }
        let index = min(max(0, position.lineIndex), scene.lines.count - 1)
        let isLast = index == scene.lines.count - 1
        let beat = StoryBeat(
            sceneID: scene.id,
            sceneTitle: scene.title,
            chapter: scene.chapter,
            line: scene.lines[index],
            lineIndex: index,
            lineCount: scene.lines.count,
            isLastLine: isLast
        )

        if isLast && scene.lastLineIsChoicePoint {
            return .choice(beat, scene.choices)
        }
        return .line(beat)
    }

    public func advanceStory() -> StoryStep {
        guard let position = state.storyPosition,
              let scene = StoryScript.scene(chapter: position.chapter, index: position.sceneIndex) else {
            return .blocked("이야기가 아직 시작되지 않았어요.")
        }
        guard !scene.lines.isEmpty else {
            return .blocked("장면이 비어 있어요.")
        }

        if pendingReply != nil {
            pendingReply = nil
            return finishScene(scene, position: position)
        }

        if position.awaitingChoice && scene.lastLineIsChoicePoint {
            let lastIndex = max(0, scene.lines.count - 1)
            let beat = StoryBeat(
                sceneID: scene.id,
                sceneTitle: scene.title,
                chapter: scene.chapter,
                line: scene.lines[lastIndex],
                lineIndex: lastIndex,
                lineCount: scene.lines.count,
                isLastLine: true
            )
            return .choice(beat, scene.choices)
        }

        let nextIndex = position.lineIndex + 1
        if nextIndex < scene.lines.count {
            var updated = position
            updated.lineIndex = nextIndex
            updated.awaitingChoice = nextIndex == scene.lines.count - 1 && scene.lastLineIsChoicePoint
            state.storyPosition = updated
            autoSave()
            return currentStep()
        }

        return finishScene(scene, position: position)
    }

    /// 선택지를 고른다. 이미 고른 선택지(깃발이 남아 있는 경우)는 다시 적용하지 않는다.
    public func chooseOption(at index: Int) -> StoryStep {
        guard let position = state.storyPosition,
              let scene = StoryScript.scene(chapter: position.chapter, index: position.sceneIndex) else {
            return .blocked("이야기가 아직 시작되지 않았어요.")
        }
        guard index >= 0, index < scene.choices.count else {
            return currentStep()
        }

        let choice = scene.choices[index]
        if let flag = choice.flag, state.hasFlag(flag) {
            if let reply = choice.reply {
                pendingReply = reply
                return currentStep()
            }
            return finishScene(scene, position: position)
        }

        for gain in choice.gains {
            state.addAffinity(gain.amount, to: gain.character)
        }
        if let flag = choice.flag {
            state.setFlag(flag)
        }
        state.stats.choices += 1
        _ = refreshDiaryMemories()

        var updated = position
        updated.awaitingChoice = false
        state.storyPosition = updated

        pendingReply = choice.reply
        if pendingReply == nil {
            return finishScene(scene, position: updated)
        }
        autoSave()
        return currentStep()
    }

    private func finishScene(_ scene: StoryScene, position: StoryPosition) -> StoryStep {
        state.add(scene.grants)
        let newly = state.unlockDiary(scene.unlocksDiary)
        let summary = SceneSummary(
            chapter: scene.chapter,
            sceneTitle: scene.title,
            thought: scene.closingThought,
            gained: scene.grants,
            unlockedDiary: newly
        )

        let scenes = StoryScript.scenes(in: scene.chapter)
        let nextSceneIndex = position.sceneIndex + 1

        if nextSceneIndex < scenes.count {
            state.storyPosition = StoryPosition(
                chapter: scene.chapter,
                sceneIndex: nextSceneIndex,
                lineIndex: 0
            )
            autoSave()
            return .sceneFinished(summary)
        }

        // 챕터 끝
        state.markCompleted(scene.chapter)
        var unlocked: [String] = []
        let chapterEntry = ForestDiary.chapterEntryID(for: scene.chapter)
        if state.unlockDiary(chapterEntry) {
            unlocked.append(chapterEntry)
        }
        if scene.chapter == .epilogue {
            if state.unlockDiary(ForestDiary.festivalEntryID) {
                unlocked.append(ForestDiary.festivalEntryID)
            }
        }
        unlocked.append(contentsOf: refreshDiaryMemories())

        state.storyPosition = nil
        pendingReply = nil

        var nextAvailable: StoryChapter?
        if let next = scene.chapter.next, ChapterRules.isUnlocked(next, in: state) {
            state.setStatus(.available, for: next)
            nextAvailable = next
        }

        autoSave()

        let message: String
        if scene.chapter == .epilogue {
            message = "이야기가 끝났어요. 숲 일기장이 가득 찼습니다."
        } else {
            message = ChapterRules.unlockMessage(for: scene.chapter, in: state)
        }

        return .completed(ChapterCompletion(
            chapter: scene.chapter,
            nextChapter: nextAvailable,
            unlockedDiary: unlocked.last,
            message: message
        ))
    }

    @discardableResult
    private func refreshDiaryMemories() -> [String] {
        var ids: [String] = []
        for character in CharacterID.allCases {
            let level = state.affinityLevel(for: character)
            ids.append(contentsOf: ForestDiary.memoryEntriesUnlocked(for: character, level: level))
        }
        return state.unlockDiary(ids)
    }

    // MARK: - 달

    /// 지금 달의 위상. 디버그 고정값이 있으면 그쪽을 따른다.
    public var currentMoonPhase: MoonPhase {
        if let override = state.debugMoonOverride { return override }
        return moonClock.phase(at: now())
    }

    public var daysUntilFullMoon: Double {
        if let override = state.debugMoonOverride {
            return override == .fullMoon ? 0 : 1
        }
        return MoonCalendar.daysUntilFullMoon(at: now())
    }

    /// 보름달 밤에만 열리는 비밀 정원이 지금 열려 있는지.
    public var isMoonlitGardenOpen: Bool {
        guard state.status(of: MoonGarden.requiredChapter) != .locked else { return false }
        return MoonGarden.isOpen(phase: currentMoonPhase)
    }

    /// 지도·채집·부엌 위쪽에 붙는 달 배지.
    public var moonBadgeLine: String {
        let phase = currentMoonPhase
        if phase.isFullMoon {
            return "\(phase.emoji) 보름달 밤 · 비밀 정원 열림"
        }
        let days = max(1, Int(daysUntilFullMoon.rounded(.up)))
        return "\(phase.emoji) \(phase.title) · 다음 보름달까지 \(days)일"
    }

    public var moonGardenLine: String {
        MoonGarden.statusLine(phase: currentMoonPhase, daysUntilFullMoon: daysUntilFullMoon)
    }

    /// 설정 화면에서 달 위상을 고정한다. nil이면 실제 날짜를 따른다.
    public func setMoonOverride(_ phase: MoonPhase?) {
        state.debugMoonOverride = phase
        lastMessage = phase.map { "달을 \($0.title)(으)로 고정했어요." } ?? "달을 실제 날짜로 되돌렸어요."
        autoSave()
    }

    // MARK: - 장소

    public func isLocationUnlocked(_ location: ForestLocation) -> Bool {
        if let pack = location.requiredPack, !state.owns(pack) { return false }
        if location.requiresFullMoon { return isMoonlitGardenOpen }
        return state.status(of: location.unlockChapter) != .locked
    }

    /// 장소를 누를 수 없을 때 보여 줄 이유.
    public func lockMessage(for location: ForestLocation) -> String {
        if let pack = location.requiredPack, !state.owns(pack) {
            return "\(location.title)은(는) 「\(pack.displayName)」에서 열려요."
        }
        if location.requiresFullMoon {
            return MoonGarden.closedMessage(daysUntilFullMoon: daysUntilFullMoon)
        }
        return "\(location.title)은 아직 열리지 않았어요. 이야기를 더 진행해 주세요."
    }

    public var unlockedLocations: [ForestLocation] {
        ForestLocation.allCases.filter { isLocationUnlocked($0) }
    }

    /// 채집 미니게임에서 실제로 만들 수 있는 재료 목록.
    public var visibleIngredients: [Ingredient] {
        Ingredient.allCases.filter { ingredient in
            if state.count(of: ingredient) > 0 { return true }
            guard let source = ingredient.sourceLocation else { return true }
            switch source {
            case .greenhouse:
                return state.owns(.greenhouse)
            case .moonlitGarden:
                return state.status(of: MoonGarden.requiredChapter) != .locked
            default:
                return true
            }
        }
    }

    // MARK: - 채집

    @discardableResult
    public func startGathering(at location: ForestLocation, seed: UInt64? = nil) -> Bool {
        refreshDailyState()
        if let pack = location.requiredPack, !state.owns(pack) {
            lastMessage = "\(location.title)은(는) 「\(pack.displayName)」에서 열려요."
            return false
        }
        guard isLocationUnlocked(location) else {
            lastMessage = lockMessage(for: location)
            return false
        }
        guard location.isGatherable else {
            lastMessage = "여기서는 채집할 것이 없어요."
            return false
        }
        guard state.spendGatherEnergy() else {
            lastMessage = "오늘 쓸 달빛 기운을 다 썼어요. 모닥불에 앉아 집중을 마치거나 우체통을 확인하면 기운이 한 칸 돌아오고, 내일 아침에는 다섯 칸이 모두 찹니다."
            return false
        }
        let chosenSeed = seed ?? UInt64.random(in: 1...UInt64.max)
        gathering = GatheringSession(location: location, seed: chosenSeed)
        cooking = nil
        simmer = nil
        simmerResult = nil
        lastMessage = "달빛 기운 1을 써서 \(location.title)(으)로 향했어요."
        autoSave()
        return true
    }

    public func tickGathering(_ delta: Double) {
        gathering?.tick(delta)
    }

    public func tapGathering(lane: Int) -> TapResult {
        guard gathering != nil else { return .nothing }
        let result = gathering?.tap(lane: lane) ?? .nothing
        if case .caught = result {
            lastMessage = result.message
        }
        return result
    }

    /// 채집을 마치고 바구니에 담는다. 중간에 나가도 지금까지 주운 것은 남는다.
    @discardableResult
    public func finishGathering() -> GatheringSummary? {
        guard let session = gathering else { return nil }
        let summary = session.summary()
        state.add(summary.harvest)
        state.add(summary.bonus)
        state.stats.gatherRounds += 1
        state.stats.totalCaught += summary.caughtCount
        state.stats.bestGatherScore = max(state.stats.bestGatherScore, summary.score)
        gathering = nil
        lastMessage = "\(summary.location.title)에서 \(summary.caughtCount)개를 주웠어요. \(summary.headline)"
        autoSave()
        return summary
    }

    /// 오늘 남은 달빛 기운. 화면에 그대로 보여 준다.
    public var energyLine: String {
        "달빛 기운 \(state.moonlightEnergy)/\(GatherBalance.maxEnergy)"
    }

    public var energyStars: String {
        let full = max(0, min(GatherBalance.maxEnergy, state.moonlightEnergy))
        return String(repeating: "●", count: full)
            + String(repeating: "○", count: max(0, GatherBalance.maxEnergy - full))
    }

    public func cancelGathering() {
        gathering = nil
    }

    // MARK: - 요리

    @discardableResult
    public func startCooking(ingredients: [Ingredient]) -> Bool {
        guard !ingredients.isEmpty, ingredients.count <= RecipeBook.maximumIngredientCount else {
            lastMessage = "재료는 한 가지에서 세 가지까지 넣을 수 있어요."
            return false
        }
        guard state.canAfford(ingredients) else {
            lastMessage = "바구니에 그 재료가 모자라요."
            return false
        }
        cooking = CookingSession(ingredients: ingredients)
        simmer = nil
        simmerResult = nil
        lastMessage = ""
        return true
    }

    public func tickCooking(_ delta: Double) {
        cooking?.tick(delta)
    }

    public func stirCooking() {
        cooking?.stir()
    }

    public var cookingQualityPreview: CookingQuality {
        cooking?.quality ?? .good
    }

    /// 지금 넣은 재료가 어떤 잼이 되는지(수첩·쪽지 기준).
    public func recipePreview(for ingredients: [Ingredient]) -> Recipe? {
        RecipeBook.recipe(
            for: ingredients,
            unlockedSecretIDs: state.secretRecipes,
            includesSeasonal: state.owns(.greenhouse)
        )
    }

    // MARK: - 마무리 불 조절(불 조절 타이밍 미니게임)

    /// 불 앞에서 재료를 익힌 뒤, 솥단지 마무리 단계를 연다.
    @discardableResult
    public func startSimmer(seed: UInt64? = nil) -> Bool {
        guard let cooking else {
            lastMessage = "솥에 잼이 없어요."
            return false
        }
        guard cooking.isFinished else {
            lastMessage = "아직 잼이 익지 않았어요. 불을 조금 더 볼까요?"
            return false
        }
        simmerResult = nil
        simmer = SimmerMinigame(seed: seed ?? UInt64.random(in: 1...UInt64.max))
        lastMessage = "마무리 불 조절을 시작해요. 바늘이 초록 구간에 올 때 맞는 손짓을 눌러 주세요."
        return true
    }

    public func tickSimmer(_ delta: Double) {
        simmer?.tick(delta)
    }

    @discardableResult
    public func pressSimmer(_ action: SimmerAction) -> SimmerPressResult {
        guard let result = simmer?.press(action) else { return .ignored }
        if simmer?.isFinished == true {
            simmerResult = simmer?.outcome()
        }
        if case .fumble(let reason) = result {
            lastMessage = reason
        }
        return result
    }

    /// 마무리 단계를 마치고 성적을 남긴다. 잼은 아직 솥에 있다.
    @discardableResult
    public func finishSimmer() -> SimmerOutcome? {
        guard let game = simmer else { return nil }
        let outcome = game.outcome()
        simmer = nil
        simmerResult = outcome
        lastMessage = outcome.message
        return outcome
    }

    /// 마무리 단계를 건너뛰고 그냥 익힌다(보너스 없음).
    public func skipSimmer() {
        simmer = nil
        simmerResult = nil
        lastMessage = "불을 고르게만 유지하고 잼을 그대로 익혔어요."
    }

    public var simmerReady: Bool {
        cooking?.isFinished == true && simmer == nil
    }

    @discardableResult
    public func finishCooking() -> CookingOutcome? {
        guard let session = cooking else { return nil }
        let baseQuality = session.quality
        let attempted = session.ingredients
        let recipe = recipePreview(for: attempted)
        let blessing = MoonBlessing.forPhase(currentMoonPhase)
        let simmered = simmerResult

        for ingredient in attempted {
            state.remove(ingredient)
        }

        var quality = baseQuality
        if let simmered, simmered.grade.qualityStep > 0 {
            quality = MoonBlessing.upgraded(quality)
        }
        if blessing.qualityUpgrade {
            quality = MoonBlessing.upgraded(quality)
        }

        var gained: [String] = []
        var isNew = false
        if let recipe {
            isNew = state.record(for: recipe.id) == nil
            state.addCooked(
                recipeID: recipe.id,
                quality: quality,
                blessingTag: blessing.tag,
                extraServings: blessing.bonusServings + (simmered?.grade.extraServings ?? 0)
            )
            state.stats.cooks += 1
            if quality == .perfect { state.stats.perfectCooks += 1 }
            let diaryID = ForestDiary.recipeEntryID(for: recipe.id)
            if state.unlockDiary(diaryID) {
                gained.append(diaryID)
            }
        }

        if let bonus = blessing.bonusIngredient, blessing.bonusCount > 0 {
            state.add(bonus, count: blessing.bonusCount)
        }

        cooking = nil
        simmer = nil
        simmerResult = nil
        autoSave()

        var message: String
        if let recipe {
            if isNew {
                message = "\(recipe.name)을(를) 처음 만들어 냈어요. \(quality.note)"
            } else {
                message = "\(recipe.name) 완성. \(quality.note)"
            }
        } else {
            let hint = RecipeBook.closestRecipe(
                to: attempted,
                unlockedSecretIDs: state.secretRecipes,
                includesSeasonal: state.owns(.greenhouse)
            ).map { " ‘\($0.name)’에 가까운 조합이에요." } ?? ""
            message = "솥단지가 뭉근한 잼이 되었어요. 수첩의 레시피와 맞지 않았어요.\(hint)"
        }

        if let simmered {
            message += " \(simmered.grade.emoji) \(simmered.grade.title)"
            if simmered.grade.extraServings > 0 {
                message += " · 한 접시 더"
            }
        }

        if blessing.hasEffect {
            message += " \(blessing.phase.emoji) \(blessing.title) — \(blessing.effectLine)"
        }

        lastMessage = message
        return CookingOutcome(
            recipe: recipe,
            attempted: attempted,
            quality: quality,
            gainedDiary: gained,
            isNewRecipe: isNew,
            message: message,
            blessing: blessing,
            simmer: simmered
        )
    }

    public func cancelCooking() {
        cooking = nil
        simmer = nil
        simmerResult = nil
    }

    // MARK: - 선물과 호감도

    public func affinityState(for character: CharacterID) -> AffinityState {
        state.affinity.first { $0.character == character } ?? AffinityState(character: character)
    }

    public func affinityLevel(for character: CharacterID) -> AffinityLevel {
        state.affinityLevel(for: character)
    }

    public func gift(recipeID: String, to character: CharacterID) -> GiftOutcome {
        guard let recipe = RecipeBook.recipe(id: recipeID) else {
            return GiftOutcome(
                succeeded: false, character: character, recipe: nil, quality: .good, gain: 0,
                levelBefore: affinityState(for: character).level,
                levelAfter: affinityState(for: character).level,
                unlockedDiary: [],
                message: "그런 요리는 없어요."
            )
        }
        guard state.servings(of: recipeID) > 0 else {
            return GiftOutcome(
                succeeded: false, character: character, recipe: recipe, quality: .good, gain: 0,
                levelBefore: affinityState(for: character).level,
                levelAfter: affinityState(for: character).level,
                unlockedDiary: [],
                message: "\(recipe.name)이 아직 없어요. 부엌에서 먼저 만들어 주세요."
            )
        }

        refreshDailyState()
        let today = state.currentDay(at: now())
        let giftIndex = state.giftsGiven(to: character, day: today)
        let factor = AffinitySystem.dailyGiftFactor(forGiftIndex: giftIndex)
        let quality = state.record(for: recipeID)?.bestQuality ?? .good
        let levelBefore = affinityState(for: character).level
        state.consumeServing(recipeID: recipeID)
        let base = AffinitySystem.baseGiftPoints(recipe: recipe, for: character)
        let raw = base + quality.giftBonus
        let gain = max(1, Int((Double(raw) * factor).rounded()))
        state.addAffinity(gain, to: character)
        state.recordGift(to: character)
        state.recordGiftToday(to: character, day: today)
        state.stats.gifts += 1
        let unlocked = refreshDiaryMemories()
        let levelAfter = affinityState(for: character).level
        autoSave()

        var message = "\(character.name)에게 \(recipe.name)을(를) 건넸어요. 호감도 +\(gain)"
        if levelAfter > levelBefore {
            message += " · \(levelAfter.title)이 되었어요"
        }
        if base == AffinitySystem.favoritePoints {
            message += " · 최애 요리!"
        }
        if factor < 1 {
            message += giftIndex == 1
                ? " · 오늘 두 번째 잼이라 반가움이 조금 잦아들었어요"
                : " · 오늘은 이미 여러 번 나눠 먹어서 반가움이 작아요"
        }
        lastMessage = message

        return GiftOutcome(
            succeeded: true,
            character: character,
            recipe: recipe,
            quality: quality,
            gain: gain,
            levelBefore: levelBefore,
            levelAfter: levelAfter,
            unlockedDiary: unlocked,
            message: message,
            factor: factor
        )
    }

    public func isFavorite(recipeID: String, for character: CharacterID) -> Bool {
        character.favoriteRecipeID == recipeID
    }

    // MARK: - 잼 병 꾸미기와 선반

    public var shelfJars: [CustomJamJar] { state.shelfJars }

    public var canDecorate: Bool { !JarShelf.isFull(state.jars) }

    /// 담가 둔 잼 한 접시로 병을 꾸며 선반에 올린다.
    @discardableResult
    public func decorateJar(recipeID: String,
                            bottle: JarBottleStyle,
                            cap: JarCapStyle,
                            ribbon: JarRibbonColor,
                            label: String) -> JarDecorationOutcome {
        guard state.servings(of: recipeID) > 0 else {
            return JarDecorationOutcome(
                succeeded: false,
                jar: nil,
                message: "그 잼이 아직 없어요. 부엌에서 먼저 담가 주세요."
            )
        }
        guard JarStyleCatalog.isUnlocked(bottle, ownsWorkshop: state.ownsWorkshop()) else {
            return JarDecorationOutcome(succeeded: false, jar: nil, message: "\(bottle.title)은(는) 병 공방 스킨에서 열려요.")
        }
        guard JarStyleCatalog.isUnlocked(cap, ownsWorkshop: state.ownsWorkshop()) else {
            return JarDecorationOutcome(succeeded: false, jar: nil, message: "\(cap.title)은(는) 병 공방 스킨에서 열려요.")
        }
        guard let slot = JarShelf.firstFreeSlot(in: state.jars) else {
            return JarDecorationOutcome(succeeded: false, jar: nil, message: "다락 선반이 가득 찼어요. 병 하나를 내려 주세요.")
        }

        state.consumeServing(recipeID: recipeID)
        let jar = CustomJamJar(
            recipeID: recipeID,
            bottle: bottle,
            cap: cap,
            ribbon: ribbon,
            label: JarShelf.sanitizedLabel(label),
            madeAt: now(),
            moonPhase: currentMoonPhase,
            slot: slot
        )
        state.placeJar(jar)
        autoSave()
        lastMessage = "\(jar.displayLabel) 병을 선반 \(slot + 1)번 칸에 올렸어요."
        return JarDecorationOutcome(
            succeeded: true,
            jar: state.jar(id: jar.id) ?? jar,
            message: lastMessage
        )
    }

    @discardableResult
    public func removeJar(id: String) -> Bool {
        let removed = state.removeJar(id: id)
        if removed {
            lastMessage = "선반에서 병을 내렸어요. 잼은 다시 부엌으로 돌아가지 않아요."
            autoSave()
        }
        return removed
    }

    // MARK: - 우체통

    public var unclaimedLetters: [MailboxLetter] { state.unclaimedLetters }

    public var mailBadgeCount: Int { state.unclaimedLetterCount }

    public var sortedLetters: [MailboxLetter] { state.sortedLetters }

    /// 날짜가 바뀌었으면 이웃이 남긴 편지를 받는다.
    @discardableResult
    public func checkMailbox(day: Int? = nil) -> [MailboxLetter] {
        refreshDailyState()
        let today = day ?? state.currentDay(at: now())
        guard today != state.lastMailCheckDay else { return [] }

        let alreadyToday = Set(state.mailbox.filter { $0.day == today }.map(\.sender))
        let candidates = MailboxSystem.letters(forDay: today, state: state, now: now())
            .filter { !alreadyToday.contains($0.sender) }
        state.lastMailCheckDay = today

        let room = max(0, MailboxSystem.capacity - state.mailbox.count)
        let accepted = Array(candidates.prefix(room))
        if !accepted.isEmpty {
            state.mailbox.append(contentsOf: accepted)
            lastMessage = "우체통에 편지 \(accepted.count)통이 들어왔어요."
        } else if !candidates.isEmpty {
            lastMessage = "우체통이 가득 찼어요. 편지를 먼저 받아 주세요."
        }
        autoSave()
        return accepted
    }

    /// 편지에 든 선물과 쪽지를 받는다.
    @discardableResult
    public func claimLetter(id: String) -> MailboxLetter? {
        guard let index = state.mailbox.firstIndex(where: { $0.id == id }) else { return nil }
        guard !state.mailbox[index].isClaimed else { return nil }

        var parts: [String] = []
        if let gift = state.mailbox[index].gift, gift.count > 0 {
            state.add(gift.ingredient, count: gift.count)
            parts.append("\(gift.ingredient.title) ×\(gift.count)")
        }
        if let recipeID = state.mailbox[index].secretRecipeID,
           !state.secretRecipes.contains(recipeID) {
            state.secretRecipes.append(recipeID)
            state.unlockDiary(ForestDiary.recipeEntryID(for: recipeID))
            if let recipe = SecretRecipeBook.recipe(id: recipeID) {
                parts.append("비밀 레시피 ‘\(recipe.name)’")
            }
        }

        state.mailbox[index].isClaimed = true
        let letter = state.mailbox[index]
        let recovered = state.recoverEnergyFromLetter()
        lastMessage = parts.isEmpty
            ? "\(letter.sender.name)의 안부를 읽었어요."
            : "\(letter.sender.name)의 편지에서 \(parts.joined(separator: " · "))을(를) 받았어요."
        if recovered {
            lastMessage += " · 달빛 기운 +1"
        }
        autoSave()
        return letter
    }

    /// 테스트·디버그용: 날짜를 하루 넘기고 우체통을 확인한다.
    @discardableResult
    public func simulateNextDay() -> [MailboxLetter] {
        state.debugDayShift += 1
        _ = refreshDailyState()
        return checkMailbox(day: state.currentDay(at: now()))
    }

    // MARK: - 집중 타이머

    public var focusSession: FocusSession? { focus }

    public func isTrackAvailable(_ track: AmbientTrack) -> Bool {
        guard let pack = track.requiredPack else { return true }
        return state.owns(pack)
    }

    @discardableResult
    public func startFocus(_ duration: FocusDuration, track: AmbientTrack) -> Bool {
        if let pack = track.requiredPack, !state.owns(pack) {
            lastMessage = "\(track.title)은(는) 「\(pack.displayName)」에서 열려요."
            return false
        }
        focus = FocusSession(duration: duration, track: track)
        lastMessage = ""
        return true
    }

    public func tickFocus(_ delta: Double) {
        focus?.tick(delta)
    }

    public func cancelFocus() {
        focus = nil
    }

    public var currentFocusRewardPreview: FocusReward? {
        guard let session = focus else { return nil }
        return FocusRules.reward(
            for: session.duration,
            track: session.track,
            ownsASMRPack: state.owns(.asmrTracks),
            isFullMoon: currentMoonPhase.isFullMoon
        )
    }

    /// 집중을 끝까지 채웠을 때만 보상을 준다.
    @discardableResult
    public func finishFocus() -> FocusReward? {
        guard let session = focus, session.isFinished else { return nil }
        let reward = FocusRules.reward(
            for: session.duration,
            track: session.track,
            ownsASMRPack: state.owns(.asmrTracks),
            isFullMoon: currentMoonPhase.isFullMoon
        )
        state.fireflyDust += reward.fireflyDust
        state.add(reward.ingredients)
        state.focusSessions += 1
        state.focusMinutes += session.duration.rawValue
        focus = nil
        var message = reward.message
        if state.recoverEnergyFromFocus() {
            message += " · 달빛 기운 +1"
        }
        lastMessage = message
        autoSave()
        return FocusReward(
            duration: reward.duration,
            track: reward.track,
            multiplier: reward.multiplier,
            fireflyDust: reward.fireflyDust,
            ingredients: reward.ingredients,
            message: message
        )
    }

    // MARK: - 이웃의 오늘의 비밀 주문서

    /// 주문서는 3장을 마치면 열린다.
    public var orderBoardUnlocked: Bool { DailyOrderBoard.isUnlocked(in: state) }

    /// 오늘의 주문. 아직 열리지 않았으면 nil.
    public var todaysOrder: DailyOrder? {
        DailyOrderBoard.order(forDay: state.currentDay(at: now()), in: state)
    }

    /// 오늘 이미 마친 주문.
    public var todaysOrderRecord: OrderRecord? {
        state.order(on: state.currentDay(at: now()))
    }

    public var orderTitle: OrderTitle { state.orderTitle }

    public var orderTrophies: [OrderTrophy] { state.unlockedTrophies }

    public var orderLine: String {
        let title = state.orderTitle
        let done = state.orders.filter(\.matched).count
        return "\(title.title) · 주문 점수 \(state.orderPoints) · 맞힌 주문 \(done)장"
    }

    /// 주문서에 낼 수 있는 잼(지금 담가 둔 것).
    public var orderCandidates: [CookedRecord] {
        state.cooked.filter { $0.servings > 0 }
    }

    /// 오늘의 주문에 잼 한 접시를 건넨다.
    @discardableResult
    public func deliverOrder(recipeID: String) -> OrderOutcome {
        refreshDailyState()
        guard orderBoardUnlocked else {
            return OrderOutcome(
                succeeded: false, order: nil, recipeID: recipeID, matched: false,
                points: 0, streak: state.orderStreak, title: state.orderTitle,
                newTrophies: [], energyGained: false,
                message: "주문서는 3장을 마친 뒤에 열려요."
            )
        }
        guard let order = todaysOrder else {
            return OrderOutcome(
                succeeded: false, order: nil, recipeID: recipeID, matched: false,
                points: 0, streak: state.orderStreak, title: state.orderTitle,
                newTrophies: [], energyGained: false,
                message: "오늘은 아직 주문서가 비어 있어요."
            )
        }
        let today = state.currentDay(at: now())
        if let done = state.order(on: today) {
            return OrderOutcome(
                succeeded: false, order: order, recipeID: done.recipeID, matched: done.matched,
                points: 0, streak: state.orderStreak, title: state.orderTitle,
                newTrophies: [], energyGained: false,
                message: "오늘 주문은 이미 마쳤어요. 내일 아침에 새 주문서가 걸립니다."
            )
        }
        guard let recipe = RecipeBook.recipe(id: recipeID), state.servings(of: recipeID) > 0 else {
            return OrderOutcome(
                succeeded: false, order: order, recipeID: recipeID, matched: false,
                points: 0, streak: state.orderStreak, title: state.orderTitle,
                newTrophies: [], energyGained: false,
                message: "그 잼이 아직 없어요. 부엌에서 먼저 담가 주세요."
            )
        }

        let matched = DailyOrderBoard.matches(recipe, clue: order.clue)
        state.consumeServing(recipeID: recipeID)

        let streakBefore = state.orderStreak
        let points = matched
            ? DailyOrderBoard.reward(for: order, streak: streakBefore)
            : DailyOrderBoard.missPoints
        state.orderPoints += points
        if matched {
            state.orderStreak = streakBefore + 1
            state.bestOrderStreak = max(state.bestOrderStreak, state.orderStreak)
        } else {
            state.orderStreak = 0
        }
        state.orders.append(OrderRecord(
            day: today,
            character: order.character,
            recipeID: recipeID,
            matched: matched,
            points: points
        ))

        let newTrophies = DailyOrderBoard.newlyUnlockedTrophies(at: state.orderPoints, alreadyOwned: state.orderTrophies)
        for trophy in newTrophies {
            state.orderTrophies.append(trophy.rawValue)
        }
        let energyGained = matched ? state.recoverEnergyFromOrder() : false

        autoSave()

        var message = DailyOrderBoard.resultLine(order: order, matched: matched, points: points)
        if energyGained { message += " · 달빛 기운 +1" }
        for trophy in newTrophies {
            message += " · \(trophy.emoji) \(trophy.title)을(를) 선반에 걸었어요"
        }
        lastMessage = message
        return OrderOutcome(
            succeeded: true,
            order: order,
            recipeID: recipeID,
            matched: matched,
            points: points,
            streak: state.orderStreak,
            title: state.orderTitle,
            newTrophies: newTrophies,
            energyGained: energyGained,
            message: message
        )
    }

    // MARK: - 확장팩

    public func owns(_ pack: ContentPack) -> Bool {
        state.owns(pack)
    }

    /// 결제가 확인된 팩을 게임에 반영한다. 처음 산 팩이면 true.
    @discardableResult
    public func grantPack(_ pack: ContentPack) -> Bool {
        let newly = state.grant(pack)
        if newly {
            lastMessage = "「\(pack.displayName)」이(가) 열렸어요."
            autoSave()
        }
        return newly
    }

    public func revokePack(_ pack: ContentPack) {
        state.revoke(pack)
        lastMessage = "「\(pack.displayName)」을(를) 닫았어요."
        autoSave()
    }

    public func setCabinStyle(_ style: CabinStyle) {
        let unlocked = CabinStyle.isUnlocked(style, ownsWorkshop: state.ownsWorkshop())
        guard unlocked else {
            lastMessage = "\(style.title)은(는) 병 공방 스킨에서 열려요."
            return
        }
        state.cabinStyle = style
        autoSave()
    }

    // MARK: - 온실 대화

    public var greenhouseNeighbours: [CharacterID] {
        state.owns(.greenhouse) ? CharacterID.expansionNeighbours : []
    }

    /// 지금 화면에 보여 줄 이웃(확장 이웃은 온실을 가진 뒤에만).
    public var visibleCharacters: [CharacterID] {
        state.visibleCharacters
    }

    /// 온실에 처음 들어갔을 때의 한 장면.
    public func greenhouseWelcome() -> DialogueOutcome? {
        guard state.owns(.greenhouse) else {
            lastMessage = "온실은 「사계절 온실 확장팩」에서 열려요."
            return nil
        }
        let isFirst = !state.hasFlag("greenhouse.opened")
        var gain = 0
        if isFirst {
            state.setFlag("greenhouse.opened")
            gain = GreenhouseDialogue.affinityGain - 2
            state.addAffinity(gain, to: .luna)
            state.addAffinity(gain, to: .coco)
            _ = refreshDiaryMemories()
            autoSave()
        }
        return DialogueOutcome(
            scene: GreenhouseDialogue.intro,
            gain: gain,
            isFirstTime: isFirst,
            message: isFirst ? "온실 문이 열렸어요." : "다시 유리 지붕 아래로."
        )
    }

    /// 온실지기와의 대화. 처음 끝까지 읽으면 호감도가 오른다.
    @discardableResult
    public func talk(to character: CharacterID) -> DialogueOutcome? {
        guard character.isExpansionCharacter else { return nil }
        guard state.owns(.greenhouse) else {
            lastMessage = "\(character.name)을(를) 만나려면 「사계절 온실 확장팩」이 필요해요."
            return nil
        }
        let isFirst = !state.hasTalked(to: character)
        guard let scene = isFirst
            ? GreenhouseDialogue.firstScene(for: character)
            : GreenhouseDialogue.closeScene(for: character) else {
            return nil
        }

        var gain = 0
        if isFirst {
            gain = GreenhouseDialogue.affinityGain
            state.addAffinity(gain, to: character)
            state.markTalked(to: character)
            _ = refreshDiaryMemories()
            autoSave()
        }

        return DialogueOutcome(
            scene: scene,
            gain: gain,
            isFirstTime: isFirst,
            message: gain > 0 ? "\(character.name)과(와) 이야기를 나눴어요. 호감도 +\(gain)" : scene.closingThought
        )
    }

    // MARK: - 일기장

    public var diaryEntries: [DiaryEntry] { ForestDiary.entries }

    public var expandedDiaryEntries: [DiaryEntry] { ForestDiary.expandedEntries }

    public func isDiaryUnlocked(_ entry: DiaryEntry) -> Bool {
        state.hasDiary(entry.id)
    }

    public var diaryProgress: DiaryProgress { state.diaryProgress }

    public var expandedDiaryProgress: DiaryProgress { state.expandedDiaryProgress }

    public func diaryEntries(kind: DiaryKind) -> [DiaryEntry] {
        ForestDiary.entries(kind: kind)
    }

    // MARK: - 안내 문구

    public var progressLine: String {
        let completed = state.completedChapters.count
        let total = StoryChapter.allCases.count
        let diary = state.diaryProgress.unlocked
        return "이야기 \(completed)/\(total) · 일기 \(diary)/\(ForestDiary.totalCount) · 바구니 \(state.totalIngredients)개 · 기운 \(state.moonlightEnergy)/\(GatherBalance.maxEnergy)"
    }

    public var nextGoalLine: String {
        guard let chapter = nextChapterToPlay else { return "이야기가 모두 끝났어요." }
        let unmet = ChapterRules.goals(for: chapter, in: state).filter { !$0.isMet }
        if unmet.isEmpty {
            return "\(chapter.shortTitle)을(를) 이어서 걸어가 보세요."
        }
        return unmet.first?.text ?? ""
    }
}

public extension StoryChapter {
    var isFinal: Bool { self == .epilogue }
}
