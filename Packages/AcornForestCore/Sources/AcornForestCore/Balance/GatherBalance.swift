import Foundation

/// 채집 재료의 등급. 드랍 확률표를 이 등급 비율로 맞춘다.
/// 흔한 재료로 잼의 바탕을 만들고, 고급 재료는 한 번 더 찾아야 나오며,
/// 희귀 재료는 달빛이 필요한 자리에서만 조금씩 나온다.
public enum IngredientTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case common
    case refined
    case rare

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .common: return "흔한 재료"
        case .refined: return "고급 재료"
        case .rare: return "희귀 재료"
        }
    }

    public var note: String {
        switch self {
        case .common: return "숲 어디서나 눈에 띄는 재료."
        case .refined: return "한두 번 더 찾아야 손에 잡히는 재료."
        case .rare: return "달빛이 필요한 자리에서만 조금씩 나오는 재료."
        }
    }
}

/// 채집터 하나에 놓인 재료와 그 무게. 무게의 합이 100이면 확률(%)로 읽힌다.
public struct GatherDrop: Codable, Hashable, Sendable {
    public let ingredient: Ingredient
    public let weight: Int

    public init(_ ingredient: Ingredient, _ weight: Int) {
        self.ingredient = ingredient
        self.weight = max(0, weight)
    }
}

/// 채집 밸런스의 한 곳. 드랍표·달빛 기운·보너스 확률이 모두 여기 숫자로 정해진다.
///
/// 드랍표는 두 모양을 쓴다.
/// - 희귀 재료가 있는 곳(달빛 비밀 정원·사계절 온실): 흔함 68% · 고급 22% · 희귀 10%
/// - 희귀 재료가 없는 곳(부엌·덤불·연못·서재·축제터): 흔함 78% · 고급 22%
///
/// 어느 쪽이든 고급 재료는 22%로 묶여 있어서, 예전처럼 한 채집터에서
/// 달조각 향신료가 쏟아지지 않는다.
public enum GatherBalance {
    public static let commonShare = 0.68
    public static let refinedShare = 0.22
    public static let rareShare = 0.10
    public static let twoTierCommonShare = 0.78

    /// 반짝이며 두 배 점수를 주는 재료가 나올 확률.
    public static let goldenChance = 0.06

    /// 하루에 쓸 수 있는 달빛 기운. 채집 한 번에 1을 쓴다.
    public static let maxEnergy = 5
    public static let energyPerSession = 1
    /// 모닥불 집중을 마치면 돌아오는 기운과, 하루에 그렇게 채울 수 있는 횟수.
    public static let focusEnergy = 1
    public static let focusEnergyCap = 2
    /// 우체통 편지를 받으면 돌아오는 기운과 하루 상한.
    public static let letterEnergy = 1
    public static let letterEnergyCap = 2
    /// 이웃의 주문을 맞히면 돌아오는 기운(상한 없음).
    public static let orderEnergy = 1

    /// 채집 한 판의 길이(초).
    public static let sessionDuration: Double = 22

    public static func share(for tier: IngredientTier) -> Double {
        switch tier {
        case .common: return commonShare
        case .refined: return refinedShare
        case .rare: return rareShare
        }
    }

    /// 드랍표의 등급별 비율. 합이 1이 되도록 정규화한다.
    public static func tierShares(of table: [GatherDrop]) -> [IngredientTier: Double] {
        let usable = table.filter { $0.weight > 0 }
        let total = usable.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return [:] }
        var shares: [IngredientTier: Double] = [:]
        for drop in usable {
            shares[drop.ingredient.tier, default: 0] += Double(drop.weight) / Double(total)
        }
        return shares
    }

    public static func totalWeight(of table: [GatherDrop]) -> Int {
        table.reduce(0) { $0 + max(0, $1.weight) }
    }

    /// 무게로 재료 하나를 뽑는다. 같은 시드면 언제나 같은 순서가 나온다.
    public static func pick(from table: [GatherDrop], using rng: inout SeededRandom) -> Ingredient? {
        let usable = table.filter { $0.weight > 0 }
        let total = usable.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return usable.first?.ingredient }
        var roll = Int.random(in: 0..<total, using: &rng)
        for drop in usable {
            if roll < drop.weight { return drop.ingredient }
            roll -= drop.weight
        }
        return usable.last?.ingredient
    }
}
