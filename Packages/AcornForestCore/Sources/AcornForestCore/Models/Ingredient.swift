import Foundation

/// 달빛 숲에서 주워 담는 재료.
/// 앞의 네 가지는 프롤로그부터 손에 잡히는 기본 재료이고,
/// 그 뒤 네 가지는 보름달 정원과 사계절 온실에서,
/// 마지막 여섯 가지는 이야기를 끝낸 뒤에만 길이 열리는 심야 구역에서 나오는 확장 재료다.
public enum Ingredient: String, CaseIterable, Codable, Identifiable, Sendable {
    case dewberry
    case fireflyNectar
    case starMossShroom
    case moonflakeSpice
    case moonlitDew
    case cherryHoney
    case mapleSap
    case snowBlossom
    case nightBellFlower
    case mothDustSugar
    case starSaltCrystal
    case cometFeather
    case emberQuince
    case frostFernSpore

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dewberry: return "이슬방울 베리"
        case .fireflyNectar: return "반딧불 꽃꿀"
        case .starMossShroom: return "별이끼 버섯"
        case .moonflakeSpice: return "달조각 향신료"
        case .moonlitDew: return "월광 이슬"
        case .cherryHoney: return "봄 벚꽃꿀"
        case .mapleSap: return "가을 단풍 수액"
        case .snowBlossom: return "겨울 눈꽃"
        case .nightBellFlower: return "밤종꽃"
        case .mothDustSugar: return "달나방 가루"
        case .starSaltCrystal: return "별소금 결정"
        case .cometFeather: return "혜성 깃털"
        case .emberQuince: return "온기 모과"
        case .frostFernSpore: return "서리 고사리솜"
        }
    }

    /// 영어 이름. README와 설정표에서만 쓴다.
    public var englishTitle: String {
        switch self {
        case .dewberry: return "Dewdrop Berry"
        case .fireflyNectar: return "Firefly Nectar"
        case .starMossShroom: return "Star-moss Shroom"
        case .moonflakeSpice: return "Moonflake Spice"
        case .moonlitDew: return "Moonlit Dew"
        case .cherryHoney: return "Cherry Blossom Honey"
        case .mapleSap: return "Maple Sap"
        case .snowBlossom: return "Snow Blossom"
        case .nightBellFlower: return "Nightbell Flower"
        case .mothDustSugar: return "Moonmoth Dust"
        case .starSaltCrystal: return "Star-salt Crystal"
        case .cometFeather: return "Comet Feather"
        case .emberQuince: return "Ember Quince"
        case .frostFernSpore: return "Frost-fern Down"
        }
    }

    public var emoji: String {
        switch self {
        case .dewberry: return "🫐"
        case .fireflyNectar: return "🍯"
        case .starMossShroom: return "🍄"
        case .moonflakeSpice: return "🌙"
        case .moonlitDew: return "💧"
        case .cherryHoney: return "🌸"
        case .mapleSap: return "🍁"
        case .snowBlossom: return "❄️"
        case .nightBellFlower: return "🛎"
        case .mothDustSugar: return "✨"
        case .starSaltCrystal: return "🧂"
        case .cometFeather: return "🪶"
        case .emberQuince: return "🍐"
        case .frostFernSpore: return "🌾"
        }
    }

    /// 어느 숲길에서 잘 보이는지에 대한 짧은 설명.
    public var note: String {
        switch self {
        case .dewberry:
            return "해가 뜨기 전에만 이슬이 맺히는 덤불에서, 반짝이는 푸른 빛으로 익는다."
        case .fireflyNectar:
            return "노을빛을 머금은 꽃에서 반딧불이가 한 방울씩 모아 둔 황금빛 꽃꿀."
        case .starMossShroom:
            return "별가루를 머금은 이끼 아래에서 자란다. 손끝에서 별이 톡톡 터진다."
        case .moonflakeSpice:
            return "보름달이 뜨는 밤에만 나무껍질에 맺히는 은빛 가루. 달바람이 불 때 걷어야 한다."
        case .moonlitDew:
            return "달이 꽉 찬 밤에만 비밀 정원의 잎맥을 따라 흐르는 물방울. 손에 닿으면 달빛이 된다."
        case .cherryHoney:
            return "온실의 벚나무가 봄에만 흘리는 꿀. 따뜻한 유리 아래에서 열두 달 봄을 견딘다."
        case .mapleSap:
            return "온실 북쪽 벽의 단풍나무에서 밤새 떨어지는 수액. 식으면 조용히 굳는다."
        case .snowBlossom:
            return "온실 천장에 내려앉은 눈이 꽃잎 모양으로 맺힌 것. 만지면 손끝이 시리다."
        case .nightBellFlower:
            return "심야에만 소리 없이 피는 종 모양 꽃. 바람이 지나가면 아주 작게 울린다."
        case .mothDustSugar:
            return "달나방의 날개에서 떨어지는 가루가 밤이슬을 만나 굳은 것. 맛이 아니라 빛으로 단맛을 낸다."
        case .starSaltCrystal:
            return "별소금 샘가에 밤새 자라난 결정. 혀에 닿으면 별 하나가 지나간 것처럼 짜릿하다."
        case .cometFeather:
            return "혜성이 지나간 밤에만 다리 난간에 걸리는 깃털. 손에 쥐면 아직 따뜻하다."
        case .emberQuince:
            return "온실 가을 칸의 모과나무가 스스로 데운 열매. 겨울 칸 벽에 대 두면 얼지 않는다."
        case .frostFernSpore:
            return "온실 겨울 칸 고사리 잎 뒤에 앉은 서리 솜. 불에 넣으면 눈처럼 사르르 풀린다."
        }
    }

    /// 채집 미니게임 기본 점수. 귀한 재료일수록 높다.
    public var gatherPoints: Int {
        switch self {
        case .dewberry: return 10
        case .starMossShroom: return 12
        case .fireflyNectar: return 15
        case .moonflakeSpice: return 20
        case .moonlitDew: return 30
        case .cherryHoney: return 18
        case .mapleSap: return 16
        case .snowBlossom: return 22
        case .nightBellFlower: return 17
        case .mothDustSugar: return 24
        case .starSaltCrystal: return 21
        case .cometFeather: return 34
        case .emberQuince: return 19
        case .frostFernSpore: return 26
        }
    }

    /// 조리 순서를 표시할 때 쓰는 짧은 색 이름(일러스트 팔레트와 맞춘다).
    public var paletteName: String {
        switch self {
        case .dewberry: return "dew"
        case .fireflyNectar: return "nectar"
        case .starMossShroom: return "starmoss"
        case .moonflakeSpice: return "moonflake"
        case .moonlitDew: return "moonlit"
        case .cherryHoney: return "cherry"
        case .mapleSap: return "maple"
        case .snowBlossom: return "snow"
        case .nightBellFlower: return "nightbell"
        case .mothDustSugar: return "mothdust"
        case .starSaltCrystal: return "starsalt"
        case .cometFeather: return "comet"
        case .emberQuince: return "quince"
        case .frostFernSpore: return "frostfern"
        }
    }

    /// 채집 등급. 드랍표의 비율은 이 등급으로 잡는다.
    /// 흔한 재료는 잼의 바탕이 되고, 고급·희귀 재료일수록 한 번 더 찾아야 한다.
    public var tier: IngredientTier {
        switch self {
        case .dewberry, .fireflyNectar, .starMossShroom, .nightBellFlower:
            return .common
        case .moonflakeSpice, .cherryHoney, .mapleSap, .mothDustSugar,
             .starSaltCrystal, .emberQuince:
            return .refined
        case .moonlitDew, .snowBlossom, .cometFeather, .frostFernSpore:
            return .rare
        }
    }

    /// 달빛이 배어 있는 재료인지. 이웃의 주문서가 '보름달 기운'을 말할 때 쓴다.
    public var carriesMoonlight: Bool {
        switch self {
        case .moonflakeSpice, .moonlitDew, .snowBlossom,
             .mothDustSugar, .starSaltCrystal, .cometFeather:
            return true
        case .dewberry, .fireflyNectar, .starMossShroom, .cherryHoney, .mapleSap,
             .nightBellFlower, .emberQuince, .frostFernSpore:
            return false
        }
    }

    /// 프롤로그~에필로그만 플레이해도 만날 수 없는 재료인지.
    /// 확장 재료는 보름달 정원(무료) · 사계절 온실(유료) · 심야 구역(이야기를 마친 뒤)에서만 나온다.
    public var isExpansionIngredient: Bool {
        switch self {
        case .dewberry, .fireflyNectar, .starMossShroom, .moonflakeSpice:
            return false
        case .moonlitDew, .cherryHoney, .mapleSap, .snowBlossom,
             .nightBellFlower, .mothDustSugar, .starSaltCrystal, .cometFeather,
             .emberQuince, .frostFernSpore:
            return true
        }
    }

    /// 이 재료가 심야 구역에서만 나오는지. 이야기를 끝낸 뒤에 열린다.
    public var isMidnightIngredient: Bool {
        switch self {
        case .nightBellFlower, .mothDustSugar, .starSaltCrystal, .cometFeather:
            return true
        case .dewberry, .fireflyNectar, .starMossShroom, .moonflakeSpice,
             .moonlitDew, .cherryHoney, .mapleSap, .snowBlossom,
             .emberQuince, .frostFernSpore:
            return false
        }
    }

    /// 확장 재료가 들어오는 장소.
    public var sourceLocation: ForestLocation? {
        switch self {
        case .dewberry, .fireflyNectar, .starMossShroom, .moonflakeSpice:
            return nil
        case .moonlitDew:
            return .moonlitGarden
        case .cherryHoney, .mapleSap, .snowBlossom, .emberQuince, .frostFernSpore:
            return .greenhouse
        case .nightBellFlower, .mothDustSugar:
            return .mothLanternBridge
        case .starSaltCrystal, .cometFeather:
            return .starSaltSpring
        }
    }

    public static var basic: [Ingredient] {
        allCases.filter { !$0.isExpansionIngredient }
    }

    public static var expansion: [Ingredient] {
        allCases.filter { $0.isExpansionIngredient }
    }

    /// 이야기를 마치면 열리는 심야 구역의 재료.
    public static var midnight: [Ingredient] {
        allCases.filter { $0.isMidnightIngredient }
    }
}

/// 바구니·창고에 담긴 재료 묶음. 저장 파일에서도 이 형태로 오간다.
public struct ItemStack: Codable, Hashable, Sendable, Identifiable {
    public var ingredient: Ingredient
    public var count: Int

    public var id: String { ingredient.rawValue }

    public init(_ ingredient: Ingredient, _ count: Int) {
        self.ingredient = ingredient
        self.count = max(0, count)
    }

    public var label: String { "\(ingredient.title) ×\(count)" }
}
