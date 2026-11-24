import Foundation

/// 레시피 수첩에 없는, 이웃이 쪽지로만 알려 주는 두 가지 잼.
public enum SecretRecipeBook {
    public static let rainyDayID = "secret-rainy-day-jam"
    public static let firstFrostID = "secret-first-frost-jelly"

    public static let all: [Recipe] = [
        Recipe(
            id: "secret-rainy-day-jam",
            name: "비 오는 날의 잼",
            ingredients: [.dewberry, .moonflakeSpice],
            story: "할머니가 수첩 뒤표지에만 적어 둔 잼. 비가 오는 날 솥단지를 열어 두면 향신료가 빗소리를 머금는다고 한다.",
            warmth: 1,
            minChapter: .chapterOne,
            isSecret: true
        ),
        Recipe(
            id: "secret-first-frost-jelly",
            name: "첫서리 젤리",
            ingredients: [.fireflyNectar, .starMossShroom],
            story: "첫서리가 내린 아침에만 굳는 젤리. 꽃꿀을 너무 일찍 넣으면 굳지 않아서, 별이끼 버섯이 다 풀린 뒤에 넣어야 한다.",
            warmth: 2,
            minChapter: .chapterTwo,
            isSecret: true
        )
    ]

    public static var ids: [String] {
        all.map(\.id)
    }

    public static func recipe(id: String) -> Recipe? {
        all.first { $0.id == id }
    }

    /// 어떤 이웃이 어떤 쪽지를 남기는지.
    public static func note(for recipeID: String, sender: CharacterID) -> String {
        switch recipeID {
        case rainyDayID:
            return "\(sender.name)이(가) 남긴 쪽지: “비 오는 날에 베리 두 줌이랑 달조각 향신료 한 꼬집. 그게 다야. 불은 약하게.”"
        case firstFrostID:
            return "\(sender.name)이(가) 남긴 쪽지: “꽃꿀은 마지막에. 별이끼 버섯이 다 풀리기 전에 넣으면 그냥 시럽이 돼.”"
        default:
            return "\(sender.name)이(가) 레시피 한 줄을 남겼어요."
        }
    }

    /// 아직 배우지 않은 비밀 레시피.
    public static func unlearned(in learned: [String]) -> [Recipe] {
        all.filter { !learned.contains($0.id) }
    }
}
