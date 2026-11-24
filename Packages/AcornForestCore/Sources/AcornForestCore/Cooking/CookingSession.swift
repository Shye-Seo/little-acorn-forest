import Foundation

/// 솥단지의 불 조절 결과. 요리의 완성도이자 선물 점수의 보정값.
public enum CookingQuality: String, Codable, CaseIterable, Sendable, Comparable {
    case burnt
    case good
    case perfect

    public var title: String {
        switch self {
        case .burnt: return "살짝 탔어요"
        case .good: return "따뜻하게 익었어요"
        case .perfect: return "완벽한 온기"
        }
    }

    public var note: String {
        switch self {
        case .burnt:
            return "불이 세서 가장자리가 눌었어요. 그래도 마음은 담겨 있어요."
        case .good:
            return "먹을 만해요. 다음엔 불을 조금만 낮춰 볼까요?"
        case .perfect:
            return "간도 온기도 딱 좋아요. 이웃이 한 숟갈 더 뜰 거예요."
        }
    }

    /// 완벽한 요리는 선물 호감도에 보너스를 준다.
    public var giftBonus: Int {
        switch self {
        case .burnt: return 0
        case .good: return 0
        case .perfect: return 3
        }
    }

    public var rank: Int {
        switch self {
        case .burnt: return 0
        case .good: return 1
        case .perfect: return 2
        }
    }

    public static func < (lhs: CookingQuality, rhs: CookingQuality) -> Bool {
        lhs.rank < rhs.rank
    }

    public var emoji: String {
        switch self {
        case .burnt: return "🫧"
        case .good: return "🍲"
        case .perfect: return "✨"
        }
    }
}

/// 불 조절 미니게임의 상태. 7초 동안 온도를 '은근한 구간'에 붙잡아 두면 완성도가 올라간다.
public struct CookingSession: Sendable, Equatable {
    public static let duration: Double = 7.0
    public static let idealBand: ClosedRange<Double> = 0.42...0.70
    public static let goodBand: ClosedRange<Double> = 0.26...0.84
    public static let heatPerSecond: Double = 0.13
    public static let stirCooling: Double = 0.18
    public static let burnThreshold: Double = 0.95

    public private(set) var ingredients: [Ingredient]
    public private(set) var elapsed: Double
    public private(set) var heat: Double
    public private(set) var stirs: Int
    public private(set) var inBandTime: Double
    public private(set) var burned: Bool

    public init(ingredients: [Ingredient]) {
        self.ingredients = ingredients
        self.elapsed = 0
        self.heat = 0.30
        self.stirs = 0
        self.inBandTime = 0
        self.burned = false
    }

    public mutating func tick(_ delta: Double) {
        guard !isFinished, delta > 0 else { return }
        let step = min(delta, Self.duration - elapsed)
        elapsed += step
        heat = min(1.0, heat + Self.heatPerSecond * step)
        if Self.idealBand.contains(heat) {
            inBandTime += step
        }
        if heat >= Self.burnThreshold {
            burned = true
        }
    }

    public mutating func stir() {
        guard !isFinished else { return }
        heat = max(0.05, heat - Self.stirCooling)
        stirs += 1
    }

    public var isFinished: Bool { elapsed >= Self.duration }

    public var progress: Double {
        min(1.0, elapsed / Self.duration)
    }

    public var remaining: Double {
        max(0, Self.duration - elapsed)
    }

    /// 불 세기를 화면에서 색으로 보여 줄 때 쓰는 구간.
    public var phase: CookingHeatPhase {
        if burned || heat > Self.goodBand.upperBound { return .scorching }
        if heat > Self.idealBand.upperBound { return .high }
        if Self.idealBand.contains(heat) { return .ideal }
        if heat >= Self.goodBand.lowerBound { return .low }
        return .faint
    }

    /// 완성도. 불이 한 번이라도 타는 지점을 넘으면 무조건 탄 요리가 된다.
    public var quality: CookingQuality {
        if burned { return .burnt }
        let ratio = elapsed > 0 ? inBandTime / elapsed : 0
        if ratio >= 0.55 { return .perfect }
        if ratio >= 0.28 { return .good }
        return .burnt
    }

    public var bandRatio: Double {
        elapsed > 0 ? inBandTime / elapsed : 0
    }
}

public enum CookingHeatPhase: String, Sendable {
    case faint
    case low
    case ideal
    case high
    case scorching

    public var title: String {
        switch self {
        case .faint: return "불씨가 시들해요"
        case .low: return "은근한 불"
        case .ideal: return "딱 좋은 온기"
        case .high: return "조금 뜨거워요"
        case .scorching: return "타고 있어요!"
        }
    }

    public var isIdeal: Bool { self == .ideal }
}

/// 요리를 마친 결과. 솥단지에서 무슨 일이 있었는지 전부 담아 둔다.
public struct CookingOutcome: Sendable, Equatable {
    public let recipe: Recipe?
    public let attempted: [Ingredient]
    public let quality: CookingQuality
    public let gainedDiary: [String]
    public let isNewRecipe: Bool
    public let message: String
    /// 완성 순간의 달 위상이 남긴 축복. 위상 효과가 있으면 값이 들어온다.
    public let blessing: MoonBlessing?

    public init(recipe: Recipe?,
                attempted: [Ingredient],
                quality: CookingQuality,
                gainedDiary: [String],
                isNewRecipe: Bool,
                message: String,
                blessing: MoonBlessing? = nil) {
        self.recipe = recipe
        self.attempted = attempted
        self.quality = quality
        self.gainedDiary = gainedDiary
        self.isNewRecipe = isNewRecipe
        self.message = message
        self.blessing = blessing
    }

    public var succeeded: Bool { recipe != nil }

    public var blessingLine: String {
        guard let blessing, blessing.hasEffect else { return "" }
        return "\(blessing.phase.emoji) \(blessing.title) · \(blessing.effectLine)"
    }
}
