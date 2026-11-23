import Foundation

/// 숲에서 주워 담는 재료 네 가지.
/// 요리 조합의 최소 단위이고, 채집 미니게임이 떨어뜨리는 물건이기도 하다.
public enum Ingredient: String, CaseIterable, Codable, Identifiable, Sendable {
    case raspberry
    case acorn
    case honeyMushroom
    case moonHerb

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .raspberry: return "산딸기"
        case .acorn: return "도토리"
        case .honeyMushroom: return "꿀버섯"
        case .moonHerb: return "달빛허브"
        }
    }

    public var emoji: String {
        switch self {
        case .raspberry: return "🍓"
        case .acorn: return "🌰"
        case .honeyMushroom: return "🍄"
        case .moonHerb: return "🌿"
        }
    }

    /// 어느 숲길에서 잘 보이는지에 대한 짧은 설명.
    public var note: String {
        switch self {
        case .raspberry:
            return "산딸기 덤불 아래, 햇살이 오래 머문 자리에 익는다."
        case .acorn:
            return "도토리 나무가 바람에 몸을 흔들면 우수수 떨어진다."
        case .honeyMushroom:
            return "비 온 뒤 그루터기 옆에서 달콤한 냄새를 풍긴다."
        case .moonHerb:
            return "반딧불이 연못가에서만 자라는, 밤에 은은히 빛나는 잎."
        }
    }

    /// 채집 미니게임 기본 점수. 귀한 재료일수록 높다.
    public var gatherPoints: Int {
        switch self {
        case .raspberry: return 10
        case .acorn: return 12
        case .honeyMushroom: return 15
        case .moonHerb: return 20
        }
    }

    /// 조리 순서를 표시할 때 쓰는 짧은 색 이름(일러스트 팔레트와 맞춘다).
    public var paletteName: String {
        switch self {
        case .raspberry: return "berry"
        case .acorn: return "chestnut"
        case .honeyMushroom: return "honey"
        case .moonHerb: return "sage"
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
