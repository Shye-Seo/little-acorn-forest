import Foundation

/// 사계절 온실 확장팩에서 열리는 레시피 세 가지와, 온실 네 칸의 구성.
public enum GreenhouseRecipes {
    public static let springID = "spring-blossom-honey-jam"
    public static let autumnID = "autumn-maple-compote"
    public static let winterID = "winter-snow-jam"

    public static let all: [Recipe] = [
        Recipe(
            id: "spring-blossom-honey-jam",
            name: "봄 벚꽃꿀 잼",
            ingredients: [.cherryHoney, .dewberry],
            story: "온실의 벚나무가 봄에만 흘리는 꿀에 이슬방울 베리를 맞춘 잼. 유리 아래에서도 계절이 오는 걸 잊지 않는 나무가 있다.",
            warmth: 1,
            minChapter: .epilogue,
            lockedByPack: .greenhouse
        ),
        Recipe(
            id: "autumn-maple-compote",
            name: "가을 단풍 콩포트",
            ingredients: [.mapleSap, .starMossShroom],
            story: "밤새 떨어진 단풍 수액에 별이끼 버섯을 풀면, 잼 빛이 붉은 등잔처럼 깊어진다. 루나는 이 잼을 겨울 창가에 두고 먹는다.",
            warmth: 2,
            minChapter: .epilogue,
            lockedByPack: .greenhouse
        ),
        Recipe(
            id: "winter-snow-jam",
            name: "겨울 눈꽃 잼",
            ingredients: [.snowBlossom, .moonflakeSpice, .moonlitDew],
            story: "천장에 앉은 눈꽃과 보름달의 이슬을 함께 넣은 잼. 뚜껑을 열면 잠깐 방 안이 겨울이 되고, 바로 다시 따뜻해진다.",
            warmth: 3,
            minChapter: .epilogue,
            lockedByPack: .greenhouse
        )
    ]

    public static var ids: [String] {
        all.map(\.id)
    }

    public static func recipe(id: String) -> Recipe? {
        all.first { $0.id == id }
    }

    /// 온실의 네 칸. 화면에서 계절 카드로 보여 준다.
    public enum Season: String, CaseIterable, Codable, Identifiable, Sendable {
        case spring
        case summer
        case autumn
        case winter

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .spring: return "봄 칸"
            case .summer: return "여름 칸"
            case .autumn: return "가을 칸"
            case .winter: return "겨울 칸"
            }
        }

        public var note: String {
            switch self {
            case .spring: return "벚나무와 조그만 화분들. 바닥이 늘 촉촉하다."
            case .summer: return "연못과 이끼돌. 코코가 이 칸에서 산다."
            case .autumn: return "단풍나무와 수액 병. 밤새 한 방울씩 떨어진다."
            case .winter: return "천장의 눈과 얼지 않는 국화. 루나가 여기서 별을 센다."
            }
        }

        public var emoji: String {
            switch self {
            case .spring: return "🌸"
            case .summer: return "🌊"
            case .autumn: return "🍁"
            case .winter: return "❄️"
            }
        }

        /// 이 칸에서 주로 나오는 재료.
        public var ingredient: Ingredient {
            switch self {
            case .spring: return .cherryHoney
            case .summer: return .dewberry
            case .autumn: return .mapleSap
            case .winter: return .snowBlossom
            }
        }
    }
}
