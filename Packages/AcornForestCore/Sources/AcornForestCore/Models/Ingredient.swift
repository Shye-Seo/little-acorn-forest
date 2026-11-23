import Foundation

/// 달빛 숲에서 주워 담는 판타지 재료 네 가지.
/// 잼 조합의 최소 단위이고, 채집 미니게임이 떨어뜨리는 물건이기도 하다.
public enum Ingredient: String, CaseIterable, Codable, Identifiable, Sendable {
    case dewberry
    case fireflyNectar
    case starMossShroom
    case moonflakeSpice

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dewberry: return "이슬방울 베리"
        case .fireflyNectar: return "반딧불 꽃꿀"
        case .starMossShroom: return "별이끼 버섯"
        case .moonflakeSpice: return "달조각 향신료"
        }
    }

    /// 영어 이름. README와 설정표에서만 쓴다.
    public var englishTitle: String {
        switch self {
        case .dewberry: return "Dewdrop Berry"
        case .fireflyNectar: return "Firefly Nectar"
        case .starMossShroom: return "Star-moss Shroom"
        case .moonflakeSpice: return "Moonflake Spice"
        }
    }

    public var emoji: String {
        switch self {
        case .dewberry: return "🫐"
        case .fireflyNectar: return "🍯"
        case .starMossShroom: return "🍄"
        case .moonflakeSpice: return "🌙"
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
        }
    }

    /// 채집 미니게임 기본 점수. 귀한 재료일수록 높다.
    public var gatherPoints: Int {
        switch self {
        case .dewberry: return 10
        case .starMossShroom: return 12
        case .fireflyNectar: return 15
        case .moonflakeSpice: return 20
        }
    }

    /// 조리 순서를 표시할 때 쓰는 짧은 색 이름(일러스트 팔레트와 맞춘다).
    public var paletteName: String {
        switch self {
        case .dewberry: return "dew"
        case .fireflyNectar: return "nectar"
        case .starMossShroom: return "starmoss"
        case .moonflakeSpice: return "moonflake"
        }
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
