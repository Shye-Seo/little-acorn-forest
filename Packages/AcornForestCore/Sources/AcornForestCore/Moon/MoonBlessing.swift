import Foundation

/// 달 위상이 잼 한 냄비에 남기는 축복. 요리를 마치는 순간의 위상으로 결정된다.
public struct MoonBlessing: Codable, Hashable, Sendable {
    public let phase: MoonPhase
    public let title: String
    public let note: String
    /// 저장 파일·일기장에 남는 태그.
    public let tag: String
    /// 완성된 잼이 한 접시 더 생기는가.
    public let bonusServings: Int
    /// 완성도를 한 단계 끌어올리는가(탄 → 보통 → 완벽).
    public let qualityUpgrade: Bool
    /// 바구니에 함께 담기는 재료.
    public let bonusIngredient: Ingredient?
    public let bonusCount: Int

    public init(phase: MoonPhase,
                title: String,
                note: String,
                tag: String,
                bonusServings: Int = 0,
                qualityUpgrade: Bool = false,
                bonusIngredient: Ingredient? = nil,
                bonusCount: Int = 0) {
        self.phase = phase
        self.title = title
        self.note = note
        self.tag = tag
        self.bonusServings = bonusServings
        self.qualityUpgrade = qualityUpgrade
        self.bonusIngredient = bonusIngredient
        self.bonusCount = bonusCount
    }

    /// 이 위상에서 잼에 붙는 한정 이름. (예: "보름달 축복 잼")
    public var variantName: String {
        "\(title) 잼"
    }

    /// 실제로 무언가 달라지는 축복인지.
    public var hasEffect: Bool {
        bonusServings > 0 || qualityUpgrade || (bonusIngredient != nil && bonusCount > 0)
    }

    /// 결과 카드에 한 줄로 쓰는 효과 설명.
    public var effectLine: String {
        var parts: [String] = []
        if bonusServings > 0 { parts.append("한 접시 더") }
        if qualityUpgrade { parts.append("완성도 한 단계 위로") }
        if let bonusIngredient, bonusCount > 0 {
            parts.append("\(bonusIngredient.title) ×\(bonusCount)")
        }
        return parts.isEmpty ? note : parts.joined(separator: " · ")
    }

    public static func forPhase(_ phase: MoonPhase) -> MoonBlessing {
        switch phase {
        case .crescent:
            return MoonBlessing(
                phase: .crescent,
                title: "초승달 이슬",
                note: "달이 막 뜬 밤이라 잎에 맺힌 이슬이 솥단지로 두 방울 따라 들어갔다.",
                tag: "blessing.crescent",
                bonusIngredient: .dewberry,
                bonusCount: 2
            )
        case .firstQuarter:
            return MoonBlessing(
                phase: .firstQuarter,
                title: "상현달의 결",
                note: "반쯤 찬 달이 불빛을 고르게 흩어 주어, 손이 흔들려도 잼이 고르게 졌다.",
                tag: "blessing.firstQuarter",
                qualityUpgrade: true
            )
        case .fullMoon:
            return MoonBlessing(
                phase: .fullMoon,
                title: "보름달 축복",
                note: "달이 꽉 찬 밤이라 솥단지가 한 번 더 끓었다. 같은 재료로 두 접시가 나왔다.",
                tag: "blessing.fullMoon",
                bonusServings: 1
            )
        case .waning:
            return MoonBlessing(
                phase: .waning,
                title: "그믐달의 여운",
                note: "달이 줄어드는 밤에는 향신료가 껍질에 조용히 앉아, 한 줌이 손에 묻어 왔다.",
                tag: "blessing.waning",
                bonusIngredient: .moonflakeSpice,
                bonusCount: 1
            )
        }
    }

    /// 한 단계 올린 완성도. 탄 잼이 완벽해지지는 않는다.
    public static func upgraded(_ quality: CookingQuality) -> CookingQuality {
        switch quality {
        case .burnt: return .good
        case .good: return .perfect
        case .perfect: return .perfect
        }
    }
}
