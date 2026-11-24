import Foundation

/// 달의 네 위상. 숲에서는 이 위상이 채집터와 잼의 성질을 바꾼다.
public enum MoonPhase: String, CaseIterable, Codable, Identifiable, Sendable {
    case crescent
    case firstQuarter
    case fullMoon
    case waning

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .crescent: return "초승달"
        case .firstQuarter: return "상현달"
        case .fullMoon: return "보름달"
        case .waning: return "그믐달"
        }
    }

    public var emoji: String {
        switch self {
        case .crescent: return "🌒"
        case .firstQuarter: return "🌓"
        case .fullMoon: return "🌕"
        case .waning: return "🌘"
        }
    }

    public var note: String {
        switch self {
        case .crescent:
            return "달이 막 눈을 뜬 밤. 잎마다 이슬이 새로 맺힌다."
        case .firstQuarter:
            return "반쯤 찬 달이 숲의 윤곽을 또렷하게 만든다. 불 조절이 잘 듣는 밤."
        case .fullMoon:
            return "달이 꽉 찬 밤. 담장이 열리고, 솥단지가 한 번 더 끓는다."
        case .waning:
            return "달이 조금씩 줄어드는 밤. 향신료가 나무껍질에 조용히 내려앉는다."
        }
    }

    /// 이 위상에만 열리는 장소가 있는지.
    public var isFullMoon: Bool { self == .fullMoon }

    public var opensSecretGarden: Bool { isFullMoon }

    /// 지도 배지에 쓰는 한 줄.
    public var badgeLine: String {
        "\(emoji) \(title)"
    }
}

/// 실제 날짜로 달의 위상을 계산한다.
/// 삭망월 평균 길이와 2000년 1월 6일의 삭(신월)을 기준점으로 삼는 근사 계산이라
/// 천문 계산 라이브러리 없이도 연중 ±1일 안쪽으로 맞는다.
public enum MoonCalendar {
    /// 평균 삭망월(일).
    public static let synodicMonth: Double = 29.530588853
    /// 2000-01-06 18:14 UTC의 삭(new moon)을 기준점으로 쓴다.
    public static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)
    /// 보름달·상현달로 인정하는 폭(±1일).
    public static let phaseWindow: Double = 1.0 / synodicMonth

    /// 0(삭) ~ 1(다음 삭) 사이의 위상 비율.
    public static func phaseFraction(at date: Date) -> Double {
        let days = date.timeIntervalSince(referenceNewMoon) / 86_400
        let remainder = days.truncatingRemainder(dividingBy: synodicMonth)
        let positive = remainder < 0 ? remainder + synodicMonth : remainder
        return positive / synodicMonth
    }

    /// 위상 비율을 네 단계로 나눈다. 보름달과 상현달은 ±1일 창을 쓴다.
    public static func phase(at date: Date) -> MoonPhase {
        let fraction = phaseFraction(at: date)
        if distance(from: fraction, to: 0.5) <= phaseWindow { return .fullMoon }
        if distance(from: fraction, to: 0.25) <= phaseWindow { return .firstQuarter }
        return fraction < 0.5 ? .crescent : .waning
    }

    /// 달의 밝기(0~1). 보름달이 1에 가깝다.
    public static func illumination(at date: Date) -> Double {
        let angle = phaseFraction(at: date) * 2 * Double.pi
        return (1 - cos(angle)) / 2
    }

    /// 다음 보름달까지 남은 일수(오늘이 보름달이면 0).
    public static func daysUntilFullMoon(at date: Date) -> Double {
        let fraction = phaseFraction(at: date)
        var gap = 0.5 - fraction
        if gap < 0 { gap += 1 }
        if gap > 0.5 { gap -= 1 }
        return gap * synodicMonth
    }

    public static func nextFullMoon(after date: Date) -> Date {
        date.addingTimeInterval(daysUntilFullMoon(at: date) * 86_400)
    }

    /// 하루 단위 날짜(UTC 기준 일련번호). 우체통의 '날짜가 바뀌었는지' 판정에 쓴다.
    public static func dayIndex(at date: Date) -> Int {
        Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    private static func distance(from lhs: Double, to rhs: Double) -> Double {
        let raw = abs(lhs - rhs)
        return min(raw, 1 - raw)
    }
}

/// 테스트·디버그에서 달 위상을 고정하는 시계.
public struct MoonClock: Sendable, Equatable {
    public var overridePhase: MoonPhase?
    public var overrideDate: Date?

    public init(overridePhase: MoonPhase? = nil, overrideDate: Date? = nil) {
        self.overridePhase = overridePhase
        self.overrideDate = overrideDate
    }

    public func phase(at date: Date) -> MoonPhase {
        if let overridePhase { return overridePhase }
        return MoonCalendar.phase(at: overrideDate ?? date)
    }

    public var isOverridden: Bool {
        overridePhase != nil || overrideDate != nil
    }
}
