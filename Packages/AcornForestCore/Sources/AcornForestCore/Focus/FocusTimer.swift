import Foundation

/// 모닥불 집중 타이머의 길이.
public enum FocusDuration: Int, CaseIterable, Codable, Identifiable, Sendable {
    case five = 5
    case fifteen = 15
    case twentyFive = 25

    public var id: Int { rawValue }

    public var title: String { "\(rawValue)분" }

    public var seconds: Double { Double(rawValue) * 60 }

    public var note: String {
        switch self {
        case .five: return "차 한 잔 끓이는 동안. 손을 멈추고 창밖을 봅니다."
        case .fifteen: return "편지 한 장을 쓰는 동안. 불이 천천히 잦아듭니다."
        case .twentyFive: return "장작 한 개가 타는 동안. 그 뒤에는 반드시 쉬어야 합니다."
        }
    }

    public var emoji: String {
        switch self {
        case .five: return "🕯"
        case .fifteen: return "🔥"
        case .twentyFive: return "🪵"
        }
    }
}

/// 모닥불 옆에서 고를 수 있는 배경 소리. 뒤의 두 가지는 ASMR 트랙 팩에서 열린다.
public enum AmbientTrack: String, CaseIterable, Codable, Identifiable, Sendable {
    case rain
    case hearth
    case simmer
    case nightInsects
    case windChime

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rain: return "빗소리"
        case .hearth: return "장작불"
        case .simmer: return "솥단지 끓는 소리"
        case .nightInsects: return "밤벌레"
        case .windChime: return "풍경소리"
        }
    }

    public var note: String {
        switch self {
        case .rain: return "처마 끝에서 물방울이 하나씩 떨어진다."
        case .hearth: return "장작이 타면서 아주 작게 톡톡 끊긴다."
        case .simmer: return "잼이 졸아드는 소리. 뽀글, 뽀글."
        case .nightInsects: return "풀숲에서 밤벌레가 짧게 운다."
        case .windChime: return "마루 끝 풍경이 바람에 한 번 흔들린다."
        }
    }

    public var requiredPack: ContentPack? {
        switch self {
        case .rain, .hearth, .simmer: return nil
        case .nightInsects, .windChime: return .asmrTracks
        }
    }

    public var isFree: Bool { requiredPack == nil }

    public var emoji: String {
        switch self {
        case .rain: return "🌧"
        case .hearth: return "🔥"
        case .simmer: return "🍯"
        case .nightInsects: return "🦗"
        case .windChime: return "🎐"
        }
    }

    public static func tracks(ownsPack: Bool) -> [AmbientTrack] {
        allCases.filter { track in
            guard let pack = track.requiredPack else { return true }
            return ownsPack && pack == .asmrTracks
        }
    }
}

/// 집중 타이머 한 번의 상태.
public struct FocusSession: Sendable, Equatable {
    public let duration: FocusDuration
    public let track: AmbientTrack
    public private(set) var elapsed: Double

    public init(duration: FocusDuration, track: AmbientTrack) {
        self.duration = duration
        self.track = track
        self.elapsed = 0
    }

    public mutating func tick(_ delta: Double) {
        guard !isFinished, delta > 0 else { return }
        elapsed = min(duration.seconds, elapsed + delta)
    }

    public var isFinished: Bool { elapsed >= duration.seconds }

    public var remaining: Double { max(0, duration.seconds - elapsed) }

    public var progress: Double {
        duration.seconds > 0 ? min(1, elapsed / duration.seconds) : 0
    }

    public var isAlmostDone: Bool { remaining <= 60 && remaining > 0 }

    /// 화면에 크게 보여 주는 남은 시간(mm:ss).
    public var timeLabel: String {
        let total = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// 집중을 마쳤을 때 받는 보상.
public struct FocusReward: Sendable, Equatable {
    public let duration: FocusDuration
    public let track: AmbientTrack
    public let multiplier: Int
    public let fireflyDust: Int
    public let ingredients: [ItemStack]
    public let message: String

    public init(duration: FocusDuration,
                track: AmbientTrack,
                multiplier: Int,
                fireflyDust: Int,
                ingredients: [ItemStack],
                message: String) {
        self.duration = duration
        self.track = track
        self.multiplier = multiplier
        self.fireflyDust = fireflyDust
        self.ingredients = ingredients
        self.message = message
    }

    public var isDoubled: Bool { multiplier > 1 }

    public var ingredientLine: String {
        ingredients.map { "\($0.ingredient.emoji) \($0.ingredient.title) ×\($0.count)" }
            .joined(separator: " · ")
    }
}

/// 타이머 보상 규칙. ASMR 트랙 팩을 가지고 있으면 두 배가 된다.
public enum FocusRules {
    public static let minutesPerReward = 5
    public static let packMultiplier = 2
    /// 보름달 밤에 집중을 마치면 월광 이슬 한 방울을 더 준다.
    public static let fullMoonBonus: Ingredient = .moonlitDew

    public static func baseUnits(for duration: FocusDuration) -> Int {
        max(1, duration.rawValue / minutesPerReward)
    }

    public static func reward(for duration: FocusDuration,
                              track: AmbientTrack,
                              ownsASMRPack: Bool,
                              isFullMoon: Bool = false) -> FocusReward {
        let multiplier = ownsASMRPack ? packMultiplier : 1
        let units = baseUnits(for: duration)
        let dust = units * multiplier
        var ingredients: [ItemStack] = []
        if units > 0 {
            ingredients.append(ItemStack(.starMossShroom, units * multiplier))
            ingredients.append(ItemStack(.fireflyNectar, multiplier))
        }
        if isFullMoon {
            ingredients.append(ItemStack(fullMoonBonus, 1))
        }

        var parts = ["반딧불이 가루 +\(dust)"]
        parts.append(contentsOf: ingredients.map { "\($0.ingredient.title) ×\($0.count)" })
        if ownsASMRPack { parts.append("ASMR 팩 2배") }
        if isFullMoon { parts.append("보름달의 선물") }

        return FocusReward(
            duration: duration,
            track: track,
            multiplier: multiplier,
            fireflyDust: dust,
            ingredients: ingredients,
            message: parts.joined(separator: " · ")
        )
    }
}
