import Foundation

/// 솥단지에 넣는 재료 조합 하나가 만드는 요리.
public struct Recipe: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let ingredients: [Ingredient]
    public let story: String
    /// 요리의 온기(1~3). 3에 가까울수록 손이 많이 가는 요리다.
    public let warmth: Int
    /// 이 요리가 처음 등장하는 이야기 지점(UI 안내용).
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
            id: "acorn-pie",
            name: "도토리 파이",
            ingredients: [.acorn, .raspberry],
            story: "할머니가 도토리 가루를 체에 두 번 내리고, 산딸기를 설탕 대신 넣던 파이. 겉은 바삭하고 속은 부드럽다.",
            warmth: 2,
            minChapter: .prologue
        ),
        Recipe(
            id: "raspberry-jam",
            name: "산딸기 잼",
            ingredients: [.raspberry, .moonHerb],
            story: "달빛허브 한 줌을 넣으면 잼이 은은한 보랏빛으로 물든다. 루비가 빵에 듬뿍 발라 먹는 걸 좋아한다.",
            warmth: 1,
            minChapter: .chapterOne
        ),
        Recipe(
            id: "mushroom-soup",
            name: "꿀버섯 수프",
            ingredients: [.honeyMushroom, .acorn],
            story: "도토리를 곱게 갈아 넣어 걸쭉하게 끓인 수프. 송이가 추운 날 제일 먼저 찾는 한 그릇이다.",
            warmth: 2,
            minChapter: .chapterOne
        ),
        Recipe(
            id: "moonlight-tea",
            name: "달빛 꿀차",
            ingredients: [.moonHerb, .honeyMushroom],
            story: "꿀버섯의 달콤한 즙에 달빛허브를 우린 차. 몽이 밤새 책을 읽을 때 옆에 두는 잔이다.",
            warmth: 1,
            minChapter: .chapterOne
        ),
        Recipe(
            id: "forest-mushroom-pie",
            name: "숲속 버섯 파이",
            ingredients: [.honeyMushroom, .acorn, .raspberry],
            story: "버섯과 도토리, 산딸기를 한 판에 겹겹이 쌓은 파이. 셋이 모여야 숲의 맛이 난다고 한다.",
            warmth: 3,
            minChapter: .chapterTwo
        ),
        Recipe(
            id: "grandma-porridge",
            name: "할머니의 도토리 죽",
            ingredients: [.acorn, .honeyMushroom, .moonHerb],
            story: "할머니가 아픈 이웃에게 늘 쑤어 주던 죽. 간이 세지 않아 밤에도 부담이 없다.",
            warmth: 2,
            minChapter: .chapterTwo
        ),
        Recipe(
            id: "starlight-cake",
            name: "별빛 축제 케이크",
            ingredients: [.raspberry, .acorn, .moonHerb],
            story: "축제 마지막에 올리는 케이크. 달빛허브를 촛불 대신 꽂으면 별이 내려앉은 것처럼 반짝인다.",
            warmth: 3,
            minChapter: .chapterThree
        )
    ]

    /// 재료를 순서 없이 늘어놓아 만든 조합 키. (예: "acorn+raspberry")
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
