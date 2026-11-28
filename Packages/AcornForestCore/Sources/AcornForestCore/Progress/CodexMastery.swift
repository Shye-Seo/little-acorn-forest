import Foundation

/// 수첩을 얼마나 채웠는지에 따라 열리는 '도감 마스터리' 보상.
///
/// 담근 잼의 종류가 문턱을 넘을 때마다 한 번씩 보상을 받는다.
/// 요리 화면에서 잼을 완성하면 엔진이 스스로 확인하고, 새로 열린 단계만 알려 준다.
public enum CodexMastery {
    public struct Tier: Identifiable, Hashable, Sendable {
        public let id: String
        /// 이 단계가 열리는 잼 종류 수.
        public let recipeCount: Int
        public let title: String
        public let note: String
        public let reward: [ItemStack]
        public let fireflyDust: Int

        public init(id: String,
                    recipeCount: Int,
                    title: String,
                    note: String,
                    reward: [ItemStack],
                    fireflyDust: Int = 0) {
            self.id = id
            self.recipeCount = recipeCount
            self.title = title
            self.note = note
            self.reward = reward
            self.fireflyDust = fireflyDust
        }

        public var rewardLine: String {
            var parts = reward.map(\.label)
            if fireflyDust > 0 { parts.append("반딧불이 가루 ×\(fireflyDust)") }
            return parts.joined(separator: " · ")
        }
    }

    public static let all: [Tier] = [
        Tier(
            id: "codex.apprentice",
            recipeCount: 8,
            title: "수첩의 첫 장을 다 채운 솜씨",
            note: "수첩 앞장의 레시피를 모두 담가 봤다. 할머니 글씨 옆에 내 글씨가 한 줄 생겼다.",
            reward: [ItemStack(.dewberry, 2), ItemStack(.fireflyNectar, 1)],
            fireflyDust: 2
        ),
        Tier(
            id: "codex.forestKeeper",
            recipeCount: 14,
            title: "숲의 잼지기",
            note: "숲에서 나는 재료로 만들 수 있는 잼의 절반을 채웠다. 이웃들이 이제 이름을 붙여 부른다.",
            reward: [ItemStack(.moonflakeSpice, 2), ItemStack(.starMossShroom, 2)],
            fireflyDust: 3
        ),
        Tier(
            id: "codex.seasonKeeper",
            recipeCount: 20,
            title: "사계절을 담는 손",
            note: "계절과 심야의 잼까지 손에 익었다. 뚜껑을 열기 전에 어떤 맛인지 알 수 있다.",
            reward: [ItemStack(.mothDustSugar, 1), ItemStack(.emberQuince, 1)],
            fireflyDust: 4
        ),
        Tier(
            id: "codex.allJars",
            recipeCount: 26,
            title: "모든 항아리의 주인",
            note: "수첩에 적힌 잼을 하나도 남기지 않고 담갔다. 이제 빈 항아리가 아깝지 않다.",
            reward: [ItemStack(.cometFeather, 1), ItemStack(.starSaltCrystal, 2)],
            fireflyDust: 6
        )
    ]

    /// 잼 종류 수에 따라 지금 열려 있어야 할 단계.
    public static func unlockedTiers(forRecipeCount count: Int) -> [Tier] {
        all.filter { count >= $0.recipeCount }
    }

    /// 이번에 새로 열린 단계.
    public static func newlyUnlocked(forRecipeCount count: Int, alreadyClaimed: [String]) -> [Tier] {
        unlockedTiers(forRecipeCount: count).filter { !alreadyClaimed.contains($0.id) }
    }

    /// 다음 문턱까지 남은 잼 수. 모두 채웠으면 nil.
    public static func nextTier(forRecipeCount count: Int) -> Tier? {
        all.first { count < $0.recipeCount }
    }

    public static func line(forRecipeCount count: Int) -> String {
        let unlocked = unlockedTiers(forRecipeCount: count).count
        if let next = nextTier(forRecipeCount: count) {
            return "도감 마스터리 \(unlocked)/\(all.count) · 다음 단계까지 잼 \(next.recipeCount - count)종"
        }
        return "도감 마스터리 \(all.count)/\(all.count) · 수첩을 모두 채웠어요"
    }
}
