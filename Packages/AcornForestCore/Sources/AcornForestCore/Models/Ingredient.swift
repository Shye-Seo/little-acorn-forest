import Foundation

/// 달빛 숲에서 주워 담는 재료.
/// 앞의 네 가지는 프롤로그부터 손에 잡히는 기본 재료이고,
/// 뒤의 네 가지는 보름달 정원과 사계절 온실에서만 나오는 확장 재료다.
public enum Ingredient: String, CaseIterable, Codable, Identifiable, Sendable {
    case dewberry
    case fireflyNectar
    case starMossShroom
    case moonflakeSpice
    case moonlitDew
    case cherryHoney
    case mapleSap
    case snowBlossom

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
        }
    }

    /// 채집 등급. 드랍표의 비율은 이 등급으로 잡는다.
    /// 흔한 재료는 잼의 바탕이 되고, 고급·희귀 재료일수록 한 번 더 찾아야 한다.
    public var tier: IngredientTier {
        switch self {
        case .dewberry, .fireflyNectar, .starMossShroom:
            return .common
        case .moonflakeSpice, .cherryHoney, .mapleSap:
            return .refined
        case .moonlitDew, .snowBlossom:
            return .rare
        }
    }

    /// 달빛이 배어 있는 재료인지. 이웃의 주문서가 '보름달 기운'을 말할 때 쓴다.
    public var carriesMoonlight: Bool {
        switch self {
        case .moonflakeSpice, .moonlitDew, .snowBlossom:
            return true
        case .dewberry, .fireflyNectar, .starMossShroom, .cherryHoney, .mapleSap:
            return false
        }
    }

    /// 프롤로그~에필로그만 플레이해도 만날 수 없는 재료인지.
    /// 확장 재료는 보름달 정원(무료) 또는 사계절 온실(유료)에서만 나온다.
    public var isExpansionIngredient: Bool {
        switch self {
        case .dewberry, .fireflyNectar, .starMossShroom, .moonflakeSpice:
            return false
        case .moonlitDew, .cherryHoney, .mapleSap, .snowBlossom:
            return true
        }
    }

    /// 확장 재료가 들어오는 장소.
    public var sourceLocation: ForestLocation? {
        switch self {
        case .dewberry, .fireflyNectar, .starMossShroom, .moonflakeSpice:
            return nil
        case .moonlitDew:
            return .moonlitGarden
        case .cherryHoney, .mapleSap, .snowBlossom:
            return .greenhouse
        }
    }

    public static var basic: [Ingredient] {
        allCases.filter { !$0.isExpansionIngredient }
    }

    public static var expansion: [Ingredient] {
        allCases.filter { $0.isExpansionIngredient }
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
