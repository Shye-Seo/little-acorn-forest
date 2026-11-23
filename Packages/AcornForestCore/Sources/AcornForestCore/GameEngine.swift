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

    public var didLevelUp: Bool { levelAfter > levelBefore }
}

/// 게임의 두뇌. 화면은 이 객체만 알면 되고, 규칙은 모두 여기에 있다.
/// 모든 변화는 즉시 `SaveStore`로 자동 저장된다.
public final class GameEngine {
    public private(set) var state: GameState
    public private(set) var gathering: GatheringSession?
    public private(set) var cooking: CookingSession?
    public private(set) var lastSavedAt: Date?
    public private(set) var lastMessage: String = ""

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

    public func startNewGame() {
        state = GameEngine.freshState()
        pendingReply = nil
        gathering = nil
        cooking = nil
        lastMessage = "할머니의 오두막 앞에 도착했어요."
        saveNow()
    }

    public func deleteSave() {
        try? saveStore.delete()
        state = GameEngine.freshState()
        pendingReply = nil
        gathering = nil
        cooking = nil
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

    // MARK: - 장소

    public func isLocationUnlocked(_ location: ForestLocation) -> Bool {
        state.status(of: location.unlockChapter) != .locked
    }

    public var unlockedLocations: [ForestLocation] {
        ForestLocation.allCases.filter { isLocationUnlocked($0) }
    }

    // MARK: - 채집

    @discardableResult
    public func startGathering(at location: ForestLocation, seed: UInt64? = nil) -> Bool {
        guard isLocationUnlocked(location) else {
            lastMessage = "\(location.title)은 아직 열리지 않았어요."
            return false
        }
        guard location.isGatherable else {
            lastMessage = "여기서는 채집할 것이 없어요."
            return false
        }
        let chosenSeed = seed ?? UInt64.random(in: 1...UInt64.max)
        gathering = GatheringSession(location: location, seed: chosenSeed)
        cooking = nil
        lastMessage = ""
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

    @discardableResult
    public func finishCooking() -> CookingOutcome? {
        guard let session = cooking else { return nil }
        let quality = session.quality
        let attempted = session.ingredients
        let recipe = RecipeBook.recipe(for: attempted)

        for ingredient in attempted {
            state.remove(ingredient)
        }

        var gained: [String] = []
        var isNew = false
        if let recipe {
            isNew = state.record(for: recipe.id) == nil
            state.addCooked(recipeID: recipe.id, quality: quality)
            state.stats.cooks += 1
            if quality == .perfect { state.stats.perfectCooks += 1 }
            let diaryID = ForestDiary.recipeEntryID(for: recipe.id)
            if state.unlockDiary(diaryID) {
                gained.append(diaryID)
            }
        }

        cooking = nil
        autoSave()

        let message: String
        if let recipe {
            if isNew {
                message = "\(recipe.name)을(를) 처음 만들어 냈어요. \(quality.note)"
            } else {
                message = "\(recipe.name) 완성. \(quality.note)"
            }
        } else {
            let hint = RecipeBook.closestRecipe(to: attempted).map { " ‘\($0.name)’에 가까운 조합이에요." } ?? ""
            message = "솥단지가 뭉근한 죽이 되었어요. 레시피가 맞지 않았어요.\(hint)"
        }

        lastMessage = message
        return CookingOutcome(
            recipe: recipe,
            attempted: attempted,
            quality: quality,
            gainedDiary: gained,
            isNewRecipe: isNew,
            message: message
        )
    }

    public func cancelCooking() {
        cooking = nil
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

        let quality = state.record(for: recipeID)?.bestQuality ?? .good
        let levelBefore = affinityState(for: character).level
        state.consumeServing(recipeID: recipeID)
        let base = AffinitySystem.baseGiftPoints(recipe: recipe, for: character)
        let gain = base + quality.giftBonus
        state.addAffinity(gain, to: character)
        state.recordGift(to: character)
        state.stats.gifts += 1
        let unlocked = refreshDiaryMemories()
        let levelAfter = affinityState(for: character).level
        autoSave()

        var message = "\(character.name)에게 \(recipe.name)을(를) 건넸어요. 호감도 +\(gain)"
        if levelAfter > levelBefore {
            message += " · \(levelAfter.title)이 되었어요"
        }
        if base == 12 {
            message += " · 최애 요리!"
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
            message: message
        )
    }

    public func isFavorite(recipeID: String, for character: CharacterID) -> Bool {
        character.favoriteRecipeID == recipeID
    }

    // MARK: - 일기장

    public var diaryEntries: [DiaryEntry] { ForestDiary.entries }

    public func isDiaryUnlocked(_ entry: DiaryEntry) -> Bool {
        state.hasDiary(entry.id)
    }

    public var diaryProgress: DiaryProgress { state.diaryProgress }

    public func diaryEntries(kind: DiaryKind) -> [DiaryEntry] {
        ForestDiary.entries(kind: kind)
    }

    // MARK: - 안내 문구

    public var progressLine: String {
        let completed = state.completedChapters.count
        let total = StoryChapter.allCases.count
        let diary = state.diary.count
        return "이야기 \(completed)/\(total) · 일기 \(diary)/\(ForestDiary.totalCount) · 바구니 \(state.totalIngredients)개"
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
