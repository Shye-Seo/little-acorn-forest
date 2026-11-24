import Foundation

/// 숲 일기장(도감) 한 칸.
public struct DiaryEntry: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let body: String
    public let kind: DiaryKind
    public let relatedID: String?

    public init(id: String,
                title: String,
                body: String,
                kind: DiaryKind,
                relatedID: String? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.kind = kind
        self.relatedID = relatedID
    }
}

public enum DiaryKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case recipe
    case memory
    case chapter
    case festival

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .recipe: return "레시피"
        case .memory: return "이웃의 기억"
        case .chapter: return "이야기"
        case .festival: return "축제"
        }
    }
}

/// 일기장 목차와 해금 규칙. 대부분은 요리·선물·챕터 완료로 자연스럽게 채워진다.
/// 기본 21칸(본편)과, 확장팩으로 늘어나는 기록을 나누어 둔다.
public enum ForestDiary {
    public static let festivalEntryID = "festival.starlight"

    /// 본편 기록. 수첩의 기본 레시피와 네 이웃만 담는다.
    public static let entries: [DiaryEntry] = {
        var list: [DiaryEntry] = []

        for recipe in RecipeBook.base {
            list.append(recipeEntry(for: recipe))
        }

        for character in CharacterID.coreNeighbours {
            list.append(contentsOf: memoryEntries(for: character))
        }

        for chapter in StoryChapter.ordered {
            list.append(DiaryEntry(
                id: chapterEntryID(for: chapter),
                title: chapter.title,
                body: chapter.subtitle,
                kind: .chapter,
                relatedID: chapter.rawValue
            ))
        }

        list.append(DiaryEntry(
            id: festivalEntryID,
            title: "별빛 축제의 밤",
            body: "네 사람의 소원이 한 식탁에 모였다. 황금 보름달 잼의 뚜껑 위로 달이 한 번 떠오르고, 숲 전체가 같은 숨을 쉬었다.",
            kind: .festival,
            relatedID: nil
        ))

        return list
    }()

    /// 확장 기록. 사계절 온실 레시피·비밀 레시피·온실지기 두 명의 기억.
    public static let expandedEntries: [DiaryEntry] = {
        var list: [DiaryEntry] = []

        for recipe in GreenhouseRecipes.all + SecretRecipeBook.all {
            list.append(recipeEntry(for: recipe))
        }

        for character in CharacterID.expansionNeighbours {
            list.append(contentsOf: memoryEntries(for: character))
        }

        return list
    }()

    public static var allEntries: [DiaryEntry] {
        entries + expandedEntries
    }

    public static func recipeEntryID(for recipeID: String) -> String {
        "recipe.\(recipeID)"
    }

    public static func memoryEntryID(for character: CharacterID, tier: Int) -> String {
        "memory.\(character.rawValue).\(tier)"
    }

    public static func chapterEntryID(for chapter: StoryChapter) -> String {
        "chapter.\(chapter.rawValue)"
    }

    public static func entry(id: String) -> DiaryEntry? {
        allEntries.first { $0.id == id }
    }

    public static func entries(kind: DiaryKind) -> [DiaryEntry] {
        entries.filter { $0.kind == kind }
    }

    public static func entries(for character: CharacterID) -> [DiaryEntry] {
        allEntries.filter { $0.kind == .memory && $0.relatedID == character.rawValue }
    }

    public static var totalCount: Int { entries.count }

    public static var expandedCount: Int { expandedEntries.count }

    /// 호감도 단계가 오르면 열리는 기억의 문턱.
    public static func memoryTierUnlocked(by level: AffinityLevel) -> Int {
        level >= .close ? 2 : (level >= .greeting ? 1 : 0)
    }

    /// 이웃의 현재 호감도에 따라 열려 있어야 할 기억 id 목록.
    public static func memoryEntriesUnlocked(for character: CharacterID, level: AffinityLevel) -> [String] {
        let tier = memoryTierUnlocked(by: level)
        guard tier > 0 else { return [] }
        return (1...tier).map { memoryEntryID(for: character, tier: $0) }
    }

    // MARK: - 항목 만들기

    private static func recipeEntry(for recipe: Recipe) -> DiaryEntry {
        DiaryEntry(
            id: recipeEntryID(for: recipe.id),
            title: recipe.name,
            body: "\(recipe.ingredientEmojiLine)\n\(recipe.story)",
            kind: .recipe,
            relatedID: recipe.id
        )
    }

    private static func memoryEntries(for character: CharacterID) -> [DiaryEntry] {
        [
            DiaryEntry(
                id: memoryEntryID(for: character, tier: 1),
                title: "\(character.name)의 기억 · 첫 만남",
                body: "\(character.name)은 \(character.species)다. \(character.personality)\n\(character.portraitNote)",
                kind: .memory,
                relatedID: character.rawValue
            ),
            DiaryEntry(
                id: memoryEntryID(for: character, tier: 2),
                title: "\(character.name)의 기억 · 소원",
                body: "\(character.name)이 별빛 축제에 걸고 있는 소원은 \(character.wish)이다.\n아직 말로는 다 하지 못했지만, 우리는 조금씩 가까워지고 있다.",
                kind: .memory,
                relatedID: character.rawValue
            )
        ]
    }
}

public struct DiaryProgress: Sendable, Equatable {
    public let unlocked: Int
    public let total: Int

    public init(unlocked: Int, total: Int) {
        self.unlocked = unlocked
        self.total = total
    }

    public var ratio: Double {
        total > 0 ? Double(unlocked) / Double(total) : 0
    }
}
