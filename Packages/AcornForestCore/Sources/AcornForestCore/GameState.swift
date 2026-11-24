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
    /// 이 잼을 담글 때 달이 남긴 축복 태그(예: "blessing.fullMoon").
    public var blessingTags: [String]

    public var id: String { recipeID }

    public init(recipeID: String,
                servings: Int = 1,
                timesCooked: Int = 1,
                perfectCount: Int = 0,
                bestQuality: CookingQuality = .good,
                blessingTags: [String] = []) {
        self.recipeID = recipeID
        self.servings = servings
        self.timesCooked = timesCooked
        self.perfectCount = perfectCount
        self.bestQuality = bestQuality
        self.blessingTags = blessingTags
    }

    public var blessingLine: String {
        blessingTags.first ?? ""
    }

    private enum CookedCodingKeys: String, CodingKey {
        case recipeID, servings, timesCooked, perfectCount, bestQuality, blessingTags
    }

    /// 달 축복 태그가 생기기 전의 저장 파일도 열린다.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CookedCodingKeys.self)
        recipeID = try container.decode(String.self, forKey: .recipeID)
        servings = try container.decodeIfPresent(Int.self, forKey: .servings) ?? 1
        timesCooked = try container.decodeIfPresent(Int.self, forKey: .timesCooked) ?? 1
        perfectCount = try container.decodeIfPresent(Int.self, forKey: .perfectCount) ?? 0
        bestQuality = try container.decodeIfPresent(CookingQuality.self, forKey: .bestQuality) ?? .good
        blessingTags = try container.decodeIfPresent([String].self, forKey: .blessingTags) ?? []
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

    // MARK: 확장 기능이 저장하는 것들

    /// 다락 선반에 진열한 잼 병.
    public var jars: [CustomJamJar]
    /// 현관 우체통에 남아 있는 편지.
    public var mailbox: [MailboxLetter]
    /// 우체통을 마지막으로 확인한 날(UTC 일련번호).
    public var lastMailCheckDay: Int
    /// 산 확장팩.
    public var purchasedPacks: [ContentPack]
    /// 오두막 벽지·조명 스킨.
    public var cabinStyle: CabinStyle
    /// 집중 타이머로 모은 반딧불이 가루.
    public var fireflyDust: Int
    public var focusSessions: Int
    public var focusMinutes: Int
    /// 우체통 쪽지로 배운 비밀 레시피 id.
    public var secretRecipes: [String]
    /// 첫 대화를 끝까지 읽은 이웃.
    public var talkedCharacters: [CharacterID]
    /// 달 위상 디버그 고정값(설정 화면에서만 바뀐다).
    public var debugMoonOverride: MoonPhase?
    /// 디버그용 '하루 넘기기'로 밀린 날짜.
    public var debugDayShift: Int

    // MARK: 하루 단위 자원

    /// 오늘 남은 달빛 기운. 채집 한 번에 1씩 쓴다.
    public var moonlightEnergy: Int
    /// 기운을 마지막으로 채운 날(일련번호). 날이 바뀌면 다시 채운다.
    public var energyDay: Int
    /// 오늘 모닥불 집중으로 채운 기운 수.
    public var focusRecoveries: Int
    /// 오늘 우체통으로 채운 기운 수.
    public var letterRecoveries: Int
    /// 선물 수를 마지막으로 센 날.
    public var giftDay: Int
    /// 오늘 이웃별로 건넨 잼 수(character.rawValue 키).
    public var giftCounts: [String: Int]

    // MARK: 오늘의 주문서

    /// 주문서 누적 점수.
    public var orderPoints: Int
    /// 연속으로 맞힌 주문 수.
    public var orderStreak: Int
    public var bestOrderStreak: Int
    /// 지금까지 마친 주문 기록.
    public var orders: [OrderRecord]
    /// 열린 선반 장식(OrderTrophy raw value).
    public var orderTrophies: [String]

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
        self.jars = []
        self.mailbox = []
        self.lastMailCheckDay = 0
        self.purchasedPacks = []
        self.cabinStyle = .attic
        self.fireflyDust = 0
        self.focusSessions = 0
        self.focusMinutes = 0
        self.secretRecipes = []
        self.talkedCharacters = []
        self.debugMoonOverride = nil
        self.debugDayShift = 0
        self.moonlightEnergy = GatherBalance.maxEnergy
        self.energyDay = 0
        self.focusRecoveries = 0
        self.letterRecoveries = 0
        self.giftDay = 0
        self.giftCounts = [:]
        self.orderPoints = 0
        self.orderStreak = 0
        self.bestOrderStreak = 0
        self.orders = []
        self.orderTrophies = []
    }

    // MARK: - 구버전 저장 파일 호환

    private enum CodingKeys: String, CodingKey {
        case formatVersion, chapters, affinity, inventory, cooked, diary, flags, stats
        case storyPosition, startedAt, completedChapters
        case jars, mailbox, lastMailCheckDay, purchasedPacks, cabinStyle
        case fireflyDust, focusSessions, focusMinutes, secretRecipes, talkedCharacters
        case debugMoonOverride, debugDayShift
        case moonlightEnergy, energyDay, focusRecoveries, letterRecoveries, giftDay, giftCounts
        case orderPoints, orderStreak, bestOrderStreak, orders, orderTrophies
    }

    /// 확장 기능이 생기기 전의 저장 파일에도 열리도록, 새 필드는 없으면 기본값으로 채운다.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fresh = GameState()
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? fresh.formatVersion
        chapters = try container.decodeIfPresent([ChapterProgress].self, forKey: .chapters) ?? fresh.chapters
        affinity = try container.decodeIfPresent([AffinityState].self, forKey: .affinity) ?? fresh.affinity
        inventory = try container.decodeIfPresent([ItemStack].self, forKey: .inventory) ?? []
        cooked = try container.decodeIfPresent([CookedRecord].self, forKey: .cooked) ?? []
        diary = try container.decodeIfPresent([String].self, forKey: .diary) ?? []
        flags = try container.decodeIfPresent([String].self, forKey: .flags) ?? []
        stats = try container.decodeIfPresent(PlayerStats.self, forKey: .stats) ?? PlayerStats()
        storyPosition = try container.decodeIfPresent(StoryPosition.self, forKey: .storyPosition)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        completedChapters = try container.decodeIfPresent([StoryChapter].self, forKey: .completedChapters) ?? []
        jars = try container.decodeIfPresent([CustomJamJar].self, forKey: .jars) ?? []
        mailbox = try container.decodeIfPresent([MailboxLetter].self, forKey: .mailbox) ?? []
        lastMailCheckDay = try container.decodeIfPresent(Int.self, forKey: .lastMailCheckDay) ?? 0
        purchasedPacks = try container.decodeIfPresent([ContentPack].self, forKey: .purchasedPacks) ?? []
        cabinStyle = try container.decodeIfPresent(CabinStyle.self, forKey: .cabinStyle) ?? .attic
        fireflyDust = try container.decodeIfPresent(Int.self, forKey: .fireflyDust) ?? 0
        focusSessions = try container.decodeIfPresent(Int.self, forKey: .focusSessions) ?? 0
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 0
        secretRecipes = try container.decodeIfPresent([String].self, forKey: .secretRecipes) ?? []
        talkedCharacters = try container.decodeIfPresent([CharacterID].self, forKey: .talkedCharacters) ?? []
        debugMoonOverride = try container.decodeIfPresent(MoonPhase.self, forKey: .debugMoonOverride)
        debugDayShift = try container.decodeIfPresent(Int.self, forKey: .debugDayShift) ?? 0
        moonlightEnergy = try container.decodeIfPresent(Int.self, forKey: .moonlightEnergy) ?? GatherBalance.maxEnergy
        energyDay = try container.decodeIfPresent(Int.self, forKey: .energyDay) ?? 0
        focusRecoveries = try container.decodeIfPresent(Int.self, forKey: .focusRecoveries) ?? 0
        letterRecoveries = try container.decodeIfPresent(Int.self, forKey: .letterRecoveries) ?? 0
        giftDay = try container.decodeIfPresent(Int.self, forKey: .giftDay) ?? 0
        giftCounts = try container.decodeIfPresent([String: Int].self, forKey: .giftCounts) ?? [:]
        orderPoints = try container.decodeIfPresent(Int.self, forKey: .orderPoints) ?? 0
        orderStreak = try container.decodeIfPresent(Int.self, forKey: .orderStreak) ?? 0
        bestOrderStreak = try container.decodeIfPresent(Int.self, forKey: .bestOrderStreak) ?? 0
        orders = try container.decodeIfPresent([OrderRecord].self, forKey: .orders) ?? []
        orderTrophies = try container.decodeIfPresent([String].self, forKey: .orderTrophies) ?? []
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
        unlockDialogueIfNeeded(for: character)
    }

    public mutating func recordGift(to character: CharacterID) {
        if let index = affinity.firstIndex(where: { $0.character == character }) {
            affinity[index].gifts += 1
        }
    }

    public var metCharacters: [CharacterID] {
        CharacterID.allCases.filter { affinityPoints(for: $0) > 0 }
    }

    /// 확장팩을 사지 않아도 만나는 네 이웃.
    public var coreNeighbourAffinities: [AffinityState] {
        affinity.filter { !$0.character.isExpansionCharacter }
    }

    /// 지금 화면에 보여 줄 이웃. 온실 이웃은 확장팩을 가진 뒤에만 등장한다.
    public var visibleCharacters: [CharacterID] {
        CharacterID.allCases.filter { character in
            !character.isExpansionCharacter || owns(.greenhouse)
        }
    }

    // MARK: - 요리

    public func record(for recipeID: String) -> CookedRecord? {
        cooked.first { $0.recipeID == recipeID }
    }

    public func servings(of recipeID: String) -> Int {
        record(for: recipeID)?.servings ?? 0
    }

    public mutating func addCooked(recipeID: String,
                                   quality: CookingQuality,
                                   blessingTag: String? = nil,
                                   extraServings: Int = 0) {
        if let index = cooked.firstIndex(where: { $0.recipeID == recipeID }) {
            cooked[index].servings += 1 + max(0, extraServings)
            cooked[index].timesCooked += 1
            if quality == .perfect { cooked[index].perfectCount += 1 }
            cooked[index].bestQuality = max(cooked[index].bestQuality, quality)
            if let blessingTag, !cooked[index].blessingTags.contains(blessingTag) {
                cooked[index].blessingTags.append(blessingTag)
            }
        } else {
            cooked.append(CookedRecord(
                recipeID: recipeID,
                servings: 1 + max(0, extraServings),
                timesCooked: 1,
                perfectCount: quality == .perfect ? 1 : 0,
                bestQuality: quality,
                blessingTags: blessingTag.map { [$0] } ?? []
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
        let baseIDs = Set(ForestDiary.entries.map(\.id))
        let unlocked = diary.filter { baseIDs.contains($0) }.count
        return DiaryProgress(unlocked: unlocked, total: ForestDiary.totalCount)
    }

    /// 확장 콘텐츠로 늘어난 기록(온실 이웃·계절 레시피·비밀 레시피)의 진행도.
    public var expandedDiaryProgress: DiaryProgress {
        let extras = ForestDiary.expandedEntries
        let unlocked = extras.filter { diary.contains($0.id) }.count
        return DiaryProgress(unlocked: unlocked, total: extras.count)
    }

    public func unlockedDiaryEntries() -> [DiaryEntry] {
        ForestDiary.entries.filter { diary.contains($0.id) }
    }

    public func unlockedExpandedDiaryEntries() -> [DiaryEntry] {
        ForestDiary.expandedEntries.filter { diary.contains($0.id) }
    }

    // MARK: - 확장팩

    public func owns(_ pack: ContentPack) -> Bool {
        purchasedPacks.contains(pack)
    }

    public func ownsWorkshop() -> Bool {
        owns(.bottleWorkshop)
    }

    /// 새로 산 팩이면 true.
    @discardableResult
    public mutating func grant(_ pack: ContentPack) -> Bool {
        guard !purchasedPacks.contains(pack) else { return false }
        purchasedPacks.append(pack)
        setFlag("store.owned.\(pack.rawValue)")
        return true
    }

    public mutating func revoke(_ pack: ContentPack) {
        purchasedPacks.removeAll { $0 == pack }
        flags.removeAll { $0 == "store.owned.\(pack.rawValue)" }
        if pack == .bottleWorkshop {
            if CabinStyle.isUnlocked(cabinStyle, ownsWorkshop: false) == false {
                cabinStyle = .attic
            }
        }
    }

    public var unlockedTracks: [AmbientTrack] {
        AmbientTrack.tracks(ownsPack: owns(.asmrTracks))
    }

    public var unlockedBottles: [JarBottleStyle] {
        JarStyleCatalog.bottles(ownsWorkshop: ownsWorkshop())
    }

    public var unlockedCaps: [JarCapStyle] {
        JarStyleCatalog.caps(ownsWorkshop: ownsWorkshop())
    }

    public var unlockedCabinStyles: [CabinStyle] {
        CabinStyle.styles(ownsWorkshop: ownsWorkshop())
    }

    // MARK: - 선반

    public var shelfJars: [CustomJamJar] {
        jars.sorted { $0.slot < $1.slot }
    }

    @discardableResult
    public mutating func placeJar(_ jar: CustomJamJar) -> Bool {
        guard !JarShelf.isFull(jars) else { return false }
        var placed = jar
        if placed.slot < 0 || placed.slot >= JarShelf.capacity || jars.contains(where: { $0.slot == placed.slot }) {
            guard let slot = JarShelf.firstFreeSlot(in: jars) else { return false }
            placed.slot = slot
        }
        jars = JarShelf.normalized(jars + [placed])
        return true
    }

    @discardableResult
    public mutating func removeJar(id: String) -> Bool {
        guard let index = jars.firstIndex(where: { $0.id == id }) else { return false }
        jars.remove(at: index)
        jars = JarShelf.repacked(jars)
        return true
    }

    public func jar(id: String) -> CustomJamJar? {
        jars.first { $0.id == id }
    }

    public func jars(of recipeID: String) -> [CustomJamJar] {
        jars.filter { $0.recipeID == recipeID }
    }

    // MARK: - 우체통

    public var unclaimedLetters: [MailboxLetter] {
        mailbox.filter { !$0.isClaimed }
    }

    public var unclaimedLetterCount: Int {
        mailbox.filter { !$0.isClaimed }.count
    }

    public var sortedLetters: [MailboxLetter] {
        mailbox.sorted { lhs, rhs in
            if lhs.day == rhs.day { return lhs.deliveredAt > rhs.deliveredAt }
            return lhs.day > rhs.day
        }
    }

    /// 오늘 날짜(디버그 하루 넘기기 포함).
    public func currentDay(at date: Date) -> Int {
        MoonCalendar.dayIndex(at: date) + debugDayShift
    }

    // MARK: - 확장 이웃 대화

    public func hasTalked(to character: CharacterID) -> Bool {
        talkedCharacters.contains(character)
    }

    public mutating func markTalked(to character: CharacterID) {
        guard !talkedCharacters.contains(character) else { return }
        talkedCharacters.append(character)
    }

    // MARK: - 하루 단위 자원(달빛 기운·선물 수)

    /// 날이 바뀌었으면 달빛 기운을 다 채우고, 오늘의 선물 수를 처음부터 센다.
    @discardableResult
    public mutating func beginNewDayIfNeeded(_ day: Int) -> Bool {
        guard day != energyDay else { return false }
        energyDay = day
        moonlightEnergy = GatherBalance.maxEnergy
        focusRecoveries = 0
        letterRecoveries = 0
        giftDay = day
        giftCounts = [:]
        return true
    }

    public var canGather: Bool {
        moonlightEnergy >= GatherBalance.energyPerSession
    }

    @discardableResult
    public mutating func spendGatherEnergy() -> Bool {
        guard canGather else { return false }
        moonlightEnergy -= GatherBalance.energyPerSession
        return true
    }

    /// 모닥불 집중을 마쳤을 때. 하루 상한까지만 기운이 들어온다.
    @discardableResult
    public mutating func recoverEnergyFromFocus() -> Bool {
        guard focusRecoveries < GatherBalance.focusEnergyCap, moonlightEnergy < GatherBalance.maxEnergy else {
            return false
        }
        focusRecoveries += 1
        moonlightEnergy = min(GatherBalance.maxEnergy, moonlightEnergy + GatherBalance.focusEnergy)
        return true
    }

    /// 우체통 편지를 받았을 때. 하루 상한까지만 기운이 들어온다.
    @discardableResult
    public mutating func recoverEnergyFromLetter() -> Bool {
        guard letterRecoveries < GatherBalance.letterEnergyCap, moonlightEnergy < GatherBalance.maxEnergy else {
            return false
        }
        letterRecoveries += 1
        moonlightEnergy = min(GatherBalance.maxEnergy, moonlightEnergy + GatherBalance.letterEnergy)
        return true
    }

    /// 주문을 맞혔을 때. 상한 없이 한 칸.
    @discardableResult
    public mutating func recoverEnergyFromOrder() -> Bool {
        guard moonlightEnergy < GatherBalance.maxEnergy else { return false }
        moonlightEnergy = min(GatherBalance.maxEnergy, moonlightEnergy + GatherBalance.orderEnergy)
        return true
    }

    /// 오늘 이 이웃에게 건넨 잼 수.
    public func giftsGiven(to character: CharacterID, day: Int) -> Int {
        guard giftDay == day else { return 0 }
        return giftCounts[character.rawValue] ?? 0
    }

    public mutating func recordGiftToday(to character: CharacterID, day: Int) {
        guard giftDay == day else {
            giftDay = day
            giftCounts = [:]
            giftCounts[character.rawValue] = 1
            return
        }
        giftCounts[character.rawValue, default: 0] += 1
    }

    // MARK: - 오늘의 주문서

    /// 그날 이미 마친 주문.
    public func order(on day: Int) -> OrderRecord? {
        orders.first { $0.day == day }
    }

    public var orderTitle: OrderTitle {
        OrderTitle.title(for: orderPoints)
    }

    public var unlockedTrophies: [OrderTrophy] {
        OrderTrophy.allCases.filter { orderTrophies.contains($0.rawValue) }
    }

    /// 대화를 처음 읽었을 때 호감도를 주고, 단짝 문턱을 넘으면 두 번째 대화를 연다.
    private mutating func unlockDialogueIfNeeded(for character: CharacterID) {
        guard character.isExpansionCharacter else { return }
        guard affinityPoints(for: character) >= AffinityLevel.close.rawValue else { return }
        setFlag("dialogue.close.\(character.rawValue)")
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
        jars = JarShelf.normalized(jars)
        purchasedPacks = Array(Set(purchasedPacks)).sorted { $0.rawValue < $1.rawValue }
        secretRecipes = Array(Set(secretRecipes)).filter { SecretRecipeBook.recipe(id: $0) != nil }.sorted()
        talkedCharacters = Array(Set(talkedCharacters)).sorted { $0.rawValue < $1.rawValue }
        mailbox = mailbox
            .filter { $0.day > 0 }
            .sorted { $0.deliveredAt > $1.deliveredAt }
        if mailbox.count > MailboxSystem.capacity {
            let claimed = mailbox.filter(\.isClaimed)
            let keeping = mailbox.filter { !$0.isClaimed }.prefix(MailboxSystem.capacity)
            mailbox = Array(keeping) + claimed.prefix(max(0, MailboxSystem.capacity - keeping.count))
        }
        if CabinStyle.isUnlocked(cabinStyle, ownsWorkshop: ownsWorkshop()) == false {
            cabinStyle = .attic
        }
        fireflyDust = max(0, fireflyDust)
        focusSessions = max(0, focusSessions)
        focusMinutes = max(0, focusMinutes)
        debugDayShift = max(0, debugDayShift)
        moonlightEnergy = min(GatherBalance.maxEnergy, max(0, moonlightEnergy))
        focusRecoveries = max(0, focusRecoveries)
        letterRecoveries = max(0, letterRecoveries)
        giftCounts = giftCounts.filter { $0.value > 0 }
        orderPoints = max(0, orderPoints)
        orderStreak = max(0, orderStreak)
        bestOrderStreak = max(orderStreak, max(0, bestOrderStreak))
        orders = orders
            .filter { $0.day > 0 }
            .reduce(into: [OrderRecord]()) { result, record in
                guard !result.contains(where: { $0.day == record.day }) else { return }
                result.append(record)
            }
            .suffix(120)
            .map { $0 }
        orderTrophies = Array(Set(orderTrophies)).filter { id in
            OrderTrophy.allCases.contains { $0.rawValue == id }
        }.sorted()
    }
}
