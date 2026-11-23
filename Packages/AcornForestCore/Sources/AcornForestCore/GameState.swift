import Foundation

/// 플레이 기록. 지도 아래 '숲의 기록' 카드에 그대로 보여 준다.
public struct PlayerStats: Codable, Hashable, Sendable {
    public var gatherRounds: Int = 0
    public var totalCaught: Int = 0
    public var bestGatherScore: Int = 0
    public var cooks: Int = 0
    public var perfectCooks: Int = 0
    public var gifts: Int = 0
    public var choices: Int = 0

    public init() {}

    public var summaryLine: String {
        "채집 \(gatherRounds)번 · 요리 \(cooks)번 · 선물 \(gifts)번"
    }
}

/// 요리해 둔 한 접시. 선물하면 하나씩 줄어든다.
public struct CookedRecord: Codable, Hashable, Sendable, Identifiable {
    public var recipeID: String
    public var servings: Int
    public var timesCooked: Int
    public var perfectCount: Int
    public var bestQuality: CookingQuality

    public var id: String { recipeID }

    public init(recipeID: String,
                servings: Int = 1,
                timesCooked: Int = 1,
                perfectCount: Int = 0,
                bestQuality: CookingQuality = .good) {
        self.recipeID = recipeID
        self.servings = servings
        self.timesCooked = timesCooked
        self.perfectCount = perfectCount
        self.bestQuality = bestQuality
    }
}

public struct AffinityState: Codable, Hashable, Sendable, Identifiable {
    public var character: CharacterID
    public var points: Int
    public var gifts: Int

    public var id: String { character.rawValue }

    public init(character: CharacterID, points: Int = 0, gifts: Int = 0) {
        self.character = character
        self.points = points
        self.gifts = gifts
    }

    public var level: AffinityLevel { AffinitySystem.level(for: points) }
}

/// 게임 전체 상태. 저장 파일의 본문이다.
public struct GameState: Codable, Hashable, Sendable {
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var chapters: [ChapterProgress]
    public var affinity: [AffinityState]
    public var inventory: [ItemStack]
    public var cooked: [CookedRecord]
    public var diary: [String]
    public var flags: [String]
    public var stats: PlayerStats
    public var storyPosition: StoryPosition?
    public var startedAt: Date
    public var completedChapters: [StoryChapter]

    public init(startedAt: Date = Date()) {
        self.formatVersion = GameState.currentFormatVersion
        self.chapters = StoryChapter.ordered.map {
            ChapterProgress(chapter: $0, status: $0 == .prologue ? .available : .locked)
        }
        self.affinity = CharacterID.allCases.map { AffinityState(character: $0) }
        self.inventory = []
        self.cooked = []
        self.diary = []
        self.flags = []
        self.stats = PlayerStats()
        self.storyPosition = nil
        self.startedAt = startedAt
        self.completedChapters = []
    }

    // MARK: - 챕터

    public func status(of chapter: StoryChapter) -> ChapterStatus {
        chapters.first { $0.chapter == chapter }?.status ?? .locked
    }

    public mutating func setStatus(_ status: ChapterStatus, for chapter: StoryChapter) {
        if let index = chapters.firstIndex(where: { $0.chapter == chapter }) {
            chapters[index].status = status
        } else {
            chapters.append(ChapterProgress(chapter: chapter, status: status))
        }
    }

    public mutating func markCompleted(_ chapter: StoryChapter) {
        setStatus(.completed, for: chapter)
        if !completedChapters.contains(chapter) {
            completedChapters.append(chapter)
        }
    }

    public var lastCompletedChapter: StoryChapter? {
        completedChapters.max { $0.order < $1.order }
    }

    public var isStoryComplete: Bool {
        status(of: .epilogue) == .completed
    }

    // MARK: - 바구니

    public func count(of ingredient: Ingredient) -> Int {
        inventory.first { $0.ingredient == ingredient }?.count ?? 0
    }

    public var totalIngredients: Int {
        inventory.reduce(0) { $0 + $1.count }
    }

    public mutating func add(_ ingredient: Ingredient, count: Int = 1) {
        guard count > 0 else { return }
        if let index = inventory.firstIndex(where: { $0.ingredient == ingredient }) {
            inventory[index].count += count
        } else {
            inventory.append(ItemStack(ingredient, count))
        }
    }

    public mutating func add(_ stacks: [ItemStack]) {
        for stack in stacks {
            add(stack.ingredient, count: stack.count)
        }
    }

    @discardableResult
    public mutating func remove(_ ingredient: Ingredient, count: Int = 1) -> Bool {
        guard count > 0, let index = inventory.firstIndex(where: { $0.ingredient == ingredient }) else {
            return false
        }
        guard inventory[index].count >= count else { return false }
        inventory[index].count -= count
        if inventory[index].count == 0 {
            inventory.remove(at: index)
        }
        return true
    }

    public func canAfford(_ ingredients: [Ingredient]) -> Bool {
        guard !ingredients.isEmpty, ingredients.count <= RecipeBook.maximumIngredientCount else { return false }
        for ingredient in Set(ingredients) where count(of: ingredient) < ingredients.filter({ $0 == ingredient }).count {
            return false
        }
        return true
    }

    public var alwaysStocked: [ItemStack] {
        GameState.startingBasket
    }

    /// 새 게임을 시작할 때 할머니의 부엌에 남아 있던 재료.
    public static let startingBasket: [ItemStack] = [
        ItemStack(.dewberry, 2),
        ItemStack(.fireflyNectar, 1)
    ]

    // MARK: - 호감도

    public func affinityPoints(for character: CharacterID) -> Int {
        affinity.first { $0.character == character }?.points ?? 0
    }

    public func affinityLevel(for character: CharacterID) -> AffinityLevel {
        AffinitySystem.level(for: affinityPoints(for: character))
    }

    public mutating func addAffinity(_ amount: Int, to character: CharacterID) {
        guard amount != 0 else { return }
        if let index = affinity.firstIndex(where: { $0.character == character }) {
            affinity[index].points = AffinitySystem.clamped(affinity[index].points + amount)
        } else {
            affinity.append(AffinityState(character: character, points: AffinitySystem.clamped(amount)))
        }
    }

    public mutating func recordGift(to character: CharacterID) {
        if let index = affinity.firstIndex(where: { $0.character == character }) {
            affinity[index].gifts += 1
        }
    }

    public var metCharacters: [CharacterID] {
        CharacterID.allCases.filter { affinityPoints(for: $0) > 0 }
    }

    // MARK: - 요리

    public func record(for recipeID: String) -> CookedRecord? {
        cooked.first { $0.recipeID == recipeID }
    }

    public func servings(of recipeID: String) -> Int {
        record(for: recipeID)?.servings ?? 0
    }

    public mutating func addCooked(recipeID: String, quality: CookingQuality) {
        if let index = cooked.firstIndex(where: { $0.recipeID == recipeID }) {
            cooked[index].servings += 1
            cooked[index].timesCooked += 1
            if quality == .perfect { cooked[index].perfectCount += 1 }
            cooked[index].bestQuality = max(cooked[index].bestQuality, quality)
        } else {
            cooked.append(CookedRecord(
                recipeID: recipeID,
                servings: 1,
                timesCooked: 1,
                perfectCount: quality == .perfect ? 1 : 0,
                bestQuality: quality
            ))
        }
    }

    @discardableResult
    public mutating func consumeServing(recipeID: String) -> Bool {
        guard let index = cooked.firstIndex(where: { $0.recipeID == recipeID }) else { return false }
        guard cooked[index].servings > 0 else { return false }
        cooked[index].servings -= 1
        if cooked[index].servings == 0 {
            cooked.remove(at: index)
        }
        return true
    }

    public var cookedRecipeIDs: [String] {
        cooked.map(\.recipeID)
    }

    public var cookedRecipeCount: Int {
        cooked.count
    }

    // MARK: - 깃발과 일기장

    public func hasFlag(_ flag: String) -> Bool {
        flags.contains(flag)
    }

    public mutating func setFlag(_ flag: String) {
        guard !flags.contains(flag) else { return }
        flags.append(flag)
    }

    public func hasDiary(_ id: String) -> Bool {
        diary.contains(id)
    }

    /// 새로 열린 항목이면 true.
    @discardableResult
    public mutating func unlockDiary(_ id: String) -> Bool {
        guard !diary.contains(id) else { return false }
        diary.append(id)
        return true
    }

    @discardableResult
    public mutating func unlockDiary(_ ids: [String]) -> [String] {
        var newlyUnlocked: [String] = []
        for id in ids where unlockDiary(id) {
            newlyUnlocked.append(id)
        }
        return newlyUnlocked
    }

    public var diaryProgress: DiaryProgress {
        DiaryProgress(unlocked: diary.count, total: ForestDiary.totalCount)
    }

    public func unlockedDiaryEntries() -> [DiaryEntry] {
        ForestDiary.entries.filter { diary.contains($0.id) }
    }

    // MARK: - 정리

    /// 저장 파일을 읽었을 때 빠진 필드를 보정한다(구버전 세이브 호환).
    public mutating func normalize() {
        formatVersion = GameState.currentFormatVersion
        for chapter in StoryChapter.ordered where !chapters.contains(where: { $0.chapter == chapter }) {
            chapters.append(ChapterProgress(chapter: chapter, status: .locked))
        }
        for character in CharacterID.allCases where !affinity.contains(where: { $0.character == character }) {
            affinity.append(AffinityState(character: character))
        }
        inventory = inventory.filter { $0.count > 0 }
        cooked = cooked.filter { $0.servings > 0 }
        diary = Array(Set(diary)).sorted()
        flags = Array(Set(flags)).sorted()
        completedChapters = Array(Set(completedChapters)).sorted { $0.order < $1.order }
    }
}
