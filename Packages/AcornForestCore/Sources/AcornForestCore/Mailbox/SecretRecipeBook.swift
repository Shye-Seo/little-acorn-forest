import Foundation

/// 레시피 수첩에 없는, 이웃이 쪽지로만 알려 주는 네 가지 잼.
public enum SecretRecipeBook {
    public static let rainyDayID = "secret-rainy-day-jam"
    public static let firstFrostID = "secret-first-frost-jelly"
    public static let midnightFarewellID = "secret-midnight-farewell-jam"
    public static let sleeplessNightID = "secret-sleepless-night-jelly"

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
        ),
        Recipe(
            id: "secret-midnight-farewell-jam",
            name: "심야의 작별 잼",
            ingredients: [.nightBellFlower, .cometFeather, .mothDustSugar],
            story: "혜성이 지나간 밤에 모루가 쪽지에 남긴 잼. 다리 위에서 나눠 먹고 나면 손님은 다음 숲으로 떠난다. 이 잼을 담가 본 사람만 다리 끝까지 배웅할 수 있다고 한다.",
            warmth: 3,
            minChapter: .epilogue,
            isSecret: true
        ),
        Recipe(
            id: "secret-sleepless-night-jelly",
            name: "잠 못 드는 밤의 젤리",
            ingredients: [.starSaltCrystal, .moonflakeSpice],
            story: "달래가 알려 준 젤리. 별소금을 한 꼬집만 넣어야 잠이 오고, 두 꼬집 넣으면 밤새 노래하게 된다. 쪽지에는 '한 꼬집'이라는 말에 밑줄이 세 번 그어져 있다.",
            warmth: 2,
            minChapter: .epilogue,
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
        case midnightFarewellID:
            return "\(sender.name)이(가) 남긴 쪽지: “밤종꽃 한 줌, 달나방 가루 한 숟갈, 그리고 혜성 깃털은 마지막에 살짝. 다리 난간에 앉아서 먹으면 좋아.”"
        case sleeplessNightID:
            return "\(sender.name)이(가) 남긴 쪽지: “별소금은 꼭 한 꼬집. 두 꼬집이면 밤이 길어져. 달조각 향신료랑 같이 굳혀.”"
        default:
            return "\(sender.name)이(가) 레시피 한 줄을 남겼어요."
        }
    }

    /// 아직 배우지 않은 비밀 레시피.
    public static func unlearned(in learned: [String]) -> [Recipe] {
        all.filter { !learned.contains($0.id) }
    }
}
