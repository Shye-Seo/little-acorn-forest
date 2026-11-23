import Foundation

/// 솥단지에 넣는 재료 조합 하나가 만드는 잼.
public struct Recipe: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let ingredients: [Ingredient]
    public let story: String
    /// 잼의 온기(1~3). 3에 가까울수록 손이 많이 가는 잼이다.
    public let warmth: Int
    /// 이 잼이 처음 등장하는 이야기 지점(UI 안내용).
    public let minChapter: StoryChapter

    public init(id: String,
                name: String,
                ingredients: [Ingredient],
                story: String,
                warmth: Int,
                minChapter: StoryChapter) {
        self.id = id
        self.name = name
        self.ingredients = ingredients
        self.story = story
        self.warmth = warmth
        self.minChapter = minChapter
    }

    public var key: String { RecipeBook.key(for: ingredients) }

    public var ingredientLine: String {
        ingredients.map(\.title).joined(separator: " · ")
    }

    public var ingredientEmojiLine: String {
        ingredients.map(\.emoji).joined(separator: " ")
    }

    /// 같은 재료를 두 번 쓰는 잼(새벽이슬 잼)만 false가 된다.
    public var hasDistinctIngredients: Bool {
        Set(ingredients).count == ingredients.count
    }
}

/// 레시피 목록과 조합 판정.
/// 조합은 **재료의 종류와 개수**만 본다. 넣는 순서는 결과에 영향을 주지 않는다.
public enum RecipeBook {
    public static let maximumIngredientCount = 3

    public static let all: [Recipe] = [
        Recipe(
            id: "dawn-dew-jam",
            name: "새벽이슬 잼",
            ingredients: [.dewberry, .dewberry],
            story: "이슬이 마르기 전에 딴 베리만 두 줌, 설탕 대신 달빛을 조금. 할머니 수첩의 첫 장에 ‘아무것도 더하지 않는 날의 잼’이라고 적혀 있다.",
            warmth: 1,
            minChapter: .prologue
        ),
        Recipe(
            id: "firefly-sparkle-jam",
            name: "반딧불 스파클 잼",
            ingredients: [.dewberry, .fireflyNectar],
            story: "꽃꿀을 마지막에 넣으면 잼 표면에서 작은 빛이 톡톡 터진다. 루비는 이 잼을 병째로 들고 숲을 한 바퀴 돈다.",
            warmth: 1,
            minChapter: .chapterOne
        ),
        Recipe(
            id: "starlight-mist-jam",
            name: "별빛 안개 잼",
            ingredients: [.dewberry, .starMossShroom],
            story: "별이끼 버섯을 약한 불에 천천히 풀면 잼 위로 은빛 김이 오른다. 몽은 그 김 위에 책을 펼쳐 두고 읽는다.",
            warmth: 2,
            minChapter: .chapterOne
        ),
        Recipe(
            id: "cloud-cotton-marmalade",
            name: "구름솜 마멀레이드",
            ingredients: [.fireflyNectar, .moonflakeSpice],
            story: "달조각 향신료를 아주 조금 넣으면 꽃꿀이 구름처럼 부풀어 오른다. 숟가락으로 뜨면 솜사탕처럼 사르르 녹는다.",
            warmth: 2,
            minChapter: .chapterOne
        ),
        Recipe(
            id: "meteor-berry-compote",
            name: "유성우 베리 콩포트",
            ingredients: [.dewberry, .starMossShroom, .moonflakeSpice],
            story: "별이끼 버섯에서 터진 별가루가 베리 사이로 내려앉는다. 유성우가 지나간 밤에만 이 색이 나온다고 한다.",
            warmth: 3,
            minChapter: .chapterTwo
        ),
        Recipe(
            id: "moonshadow-herb-jelly",
            name: "달그림자 허브 젤리",
            ingredients: [.starMossShroom, .moonflakeSpice],
            story: "별이끼 버섯을 우린 물에 달조각 향신료를 풀어 굳힌 젤리. 향신료가 허브처럼 향기를 내서 ‘허브 젤리’라는 이름이 붙었다.",
            warmth: 2,
            minChapter: .chapterTwo
        ),
        Recipe(
            id: "golden-fullmoon-jam",
            name: "황금 보름달 잼",
            ingredients: [.fireflyNectar, .starMossShroom, .moonflakeSpice],
            story: "세 가지 빛을 한 항아리에 담은 축제의 잼. 뚜껑을 열면 보름달이 항아리 안에서 한 번 떠오른다고 한다.",
            warmth: 3,
            minChapter: .chapterThree
        )
    ]

    /// 재료를 순서 없이 늘어놓아 만든 조합 키. (예: "dewberry+fireflyNectar")
    public static func key(for ingredients: [Ingredient]) -> String {
        ingredients.map(\.rawValue).sorted().joined(separator: "+")
    }

    public static func recipe(for ingredients: [Ingredient]) -> Recipe? {
        guard !ingredients.isEmpty else { return nil }
        let target = key(for: ingredients)
        return all.first { $0.key == target }
    }

    public static func recipe(id: String) -> Recipe? {
        all.first { $0.id == id }
    }

    /// 조합에 실패했을 때 보여 줄 힌트. 가장 가까운 레시피를 골라 준다.
    public static func closestRecipe(to ingredients: [Ingredient]) -> Recipe? {
        guard !ingredients.isEmpty else { return nil }
        let target = Set(ingredients)
        var best: (recipe: Recipe, overlap: Int, distance: Int)?
        for recipe in all {
            let overlap = target.intersection(Set(recipe.ingredients)).count
            let distance = abs(recipe.ingredients.count - ingredients.count)
            if let current = best {
                if overlap > current.overlap || (overlap == current.overlap && distance < current.distance) {
                    best = (recipe, overlap, distance)
                }
            } else if overlap > 0 {
                best = (recipe, overlap, distance)
            }
        }
        return best?.recipe
    }

    /// 아직 만들어 보지 않은 레시피 수를 세는 데 쓴다.
    public static func unCooked(in state: GameState) -> [Recipe] {
        all.filter { state.record(for: $0.id) == nil }
    }
}
