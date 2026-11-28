import Foundation

/// 이야기를 끝낸 뒤에만 열리는 심야 구역의 레시피 아홉 가지.
///
/// 달나방 등불다리와 별소금 샘에서만 나오는 재료(밤종꽃·달나방 가루·별소금 결정·혜성 깃털)를 쓴다.
/// 이야기가 끝나기 전에는 수첩에 나타나지 않고, 조합 판정에서도 빠진다.
public enum MidnightRecipes {
    public static let bellCottonID = "midnight-bell-cotton-jam"
    public static let starSaltGlassID = "star-salt-berry-glass-jam"
    public static let cometTrailID = "comet-trail-compote"
    public static let bellMoonJellyID = "nightbell-moon-jelly"
    public static let mothLanternID = "moth-lantern-jam"
    public static let starlightMarmaladeID = "midnight-starlight-marmalade"
    public static let mothNectarID = "moth-nectar-jam"
    public static let saltEmberID = "star-salt-ember-jam"
    public static let cometFrostID = "comet-frost-jam"

    public static let all: [Recipe] = [
        Recipe(
            id: "midnight-bell-cotton-jam",
            name: "밤종꽃 솜잼",
            ingredients: [.nightBellFlower, .mothDustSugar],
            story: "종 모양 꽃잎을 살짝 데워 달나방 가루를 얹으면, 잼이 솜처럼 부풀며 밤이 한 겹 접힌다. 달래가 처음 이 잼을 맛보고 밤새 노래를 불렀다는 이야기가 있다.",
            warmth: 1,
            minChapter: .epilogue
        ),
        Recipe(
            id: "star-salt-berry-glass-jam",
            name: "별소금 베리 유리잼",
            ingredients: [.starSaltCrystal, .dewberry],
            story: "별소금 결정을 아주 조금 풀면 잼 표면이 유리처럼 맑아진다. 숟가락으로 두드리면 딸랑, 소리가 난다. 모루는 이 잼을 우편 자루에 넣고 다니며 길 잃은 밤손님에게 나눠 준다.",
            warmth: 2,
            minChapter: .epilogue
        ),
        Recipe(
            id: "comet-trail-compote",
            name: "혜성 꼬리 콩포트",
            ingredients: [.cometFeather, .nightBellFlower],
            story: "혜성 깃털을 넣고 약한 불에 오래 두면 잼 위로 길게 빛줄기가 남는다. 그 줄기는 밤이 새도록 사라지지 않는다.",
            warmth: 3,
            minChapter: .epilogue
        ),
        Recipe(
            id: "nightbell-moon-jelly",
            name: "밤종꽃 달향 젤리",
            ingredients: [.nightBellFlower, .moonflakeSpice],
            story: "밤종꽃을 우린 물에 달조각 향신료를 풀어 굳힌 젤리. 흔들면 종소리 대신 달 향이 먼저 퍼진다.",
            warmth: 1,
            minChapter: .epilogue
        ),
        Recipe(
            id: "moth-lantern-jam",
            name: "달나방 등불 잼",
            ingredients: [.mothDustSugar, .starSaltCrystal, .moonlitDew],
            story: "달나방 가루와 별소금에 월광 이슬을 마지막에 넣으면, 항아리 안에서 작은 등불이 하나 켜진다. 뚜껑을 열면 그 등불이 다리 위로 한 번 떠오른다.",
            warmth: 3,
            minChapter: .epilogue
        ),
        Recipe(
            id: "midnight-starlight-marmalade",
            name: "심야 별빛 마멀레이드",
            ingredients: [.cometFeather, .mothDustSugar],
            story: "혜성 깃털을 결대로 찢어 넣으면 잼 속에 별이 여러 개 흩어진다. 달래는 이 잼을 새벽 세 시에만 꺼내 먹는다.",
            warmth: 3,
            minChapter: .epilogue
        ),
        Recipe(
            id: "moth-nectar-jam",
            name: "달나방 꽃꿀 잼",
            ingredients: [.mothDustSugar, .fireflyNectar],
            story: "낮에 모은 꽃꿀에 밤의 가루를 얹은 잼. 반딧불이와 달나방이 같은 항아리 앞에 앉아 있는 밤이 있다.",
            warmth: 2,
            minChapter: .epilogue
        ),
        Recipe(
            id: "star-salt-ember-jam",
            name: "별소금 온기 잼",
            ingredients: [.starSaltCrystal, .emberQuince],
            story: "온기 모과를 으깨 별소금으로 간을 맞춘 잼. 짠맛이 먼저 오고, 뒤늦게 봄처럼 따뜻해진다. 온실 가을 칸과 심야 구역이 한 항아리에 만나는 잼이다.",
            warmth: 2,
            minChapter: .epilogue
        ),
        Recipe(
            id: "comet-frost-jam",
            name: "혜성 서리 잼",
            ingredients: [.cometFeather, .frostFernSpore],
            story: "서리 고사리솜을 불에 풀면 눈처럼 사라지고, 그 자리에 혜성 깃털의 빛만 남는다. 겨울 창가에 두면 유리가 조금 덜 얼어붙는다.",
            warmth: 3,
            minChapter: .epilogue
        )
    ]

    public static var ids: [String] {
        all.map(\.id)
    }

    public static func recipe(id: String) -> Recipe? {
        all.first { $0.id == id }
    }

    /// 심야 구역의 이야기가 열리는 조건. 이야기를 끝까지 걸어야 한다.
    public static var requiresStoryComplete: Bool { true }
}
