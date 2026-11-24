import Foundation

/// 솥단지 마무리에서 누르는 두 가지 손짓.
public enum SimmerAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case lowerHeat
    case stirWooden

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .lowerHeat: return "불 줄이기"
        case .stirWooden: return "나무 주걱 젓기"
        }
    }

    public var emoji: String {
        switch self {
        case .lowerHeat: return "🔥"
        case .stirWooden: return "🥄"
        }
    }

    /// 이웃이 부탁하는 말투. 미니게임 위쪽에 한 줄로 뜬다.
    public var hint: String {
        switch self {
        case .lowerHeat: return "지글지글— 지금은 불을 낮출 때예요"
        case .stirWooden: return "뭉근해지려면 한 번 저어 주세요"
        }
    }
}

/// 마무리 단계의 부탁 하나. 정해진 시간 안에 황금 구간에서 맞는 손짓을 해야 한다.
public struct SimmerRequest: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let action: SimmerAction
    public let bandStart: Double
    public let bandEnd: Double
    public let opensAt: Double
    public let closesAt: Double

    public init(id: Int,
                action: SimmerAction,
                bandStart: Double,
                bandEnd: Double,
                opensAt: Double,
                closesAt: Double) {
        self.id = id
        self.action = action
        self.bandStart = bandStart
        self.bandEnd = bandEnd
        self.opensAt = opensAt
        self.closesAt = closesAt
    }

    public var band: ClosedRange<Double> { bandStart...bandEnd }

    public var bandCenter: Double { (bandStart + bandEnd) / 2 }

    /// 구간 안에서도 가운데 절반은 '황금빛' 판정.
    public var goldenBand: ClosedRange<Double> {
        let half = (bandEnd - bandStart) * SimmerMinigame.goldenShare / 2
        return max(0, bandCenter - half)...min(1, bandCenter + half)
    }

    public func contains(_ needle: Double) -> Bool { band.contains(needle) }

    public func isGolden(_ needle: Double) -> Bool { goldenBand.contains(needle) }
}

/// 손짓을 눌렀을 때의 결과.
public enum SimmerPressResult: Sendable, Equatable {
    case hit(points: Int, golden: Bool)
    case fumble(reason: String)
    case ignored

    public var message: String {
        switch self {
        case .hit(let points, let golden):
            return golden ? "황금빛 온기! +\(points)" : "온기가 고르게 폈어요 +\(points)"
        case .fumble(let reason):
            return reason
        case .ignored:
            return ""
        }
    }
}

/// 마무리 불 조절의 최종 성적.
public enum SimmerGrade: String, Codable, CaseIterable, Sendable {
    case fumbled
    case steady
    case golden

    public var title: String {
        switch self {
        case .fumbled: return "솥이 조금 졸았어요"
        case .steady: return "온기가 고르게 폈어요"
        case .golden: return "황금빛 온기"
        }
    }

    public var note: String {
        switch self {
        case .fumbled:
            return "손이 조금 늦었지만 잼은 잼이에요. 다음엔 숨을 한 번 고르고 누르면 좋아요."
        case .steady:
            return "불이 고르게 돌았어요. 이웃이 한 숟갈 더 뜰 맛이에요."
        case .golden:
            return "솥 가장자리까지 같은 온기로 졸았어요. 뚜껑을 열면 빛이 한 번 떠오를 거예요."
        }
    }

    /// 마무리 성적이 완성도를 한 단계 끌어올리는가.
    public var qualityStep: Int {
        self == .golden ? 1 : 0
    }

    /// 한 접시 더 나오는가.
    public var extraServings: Int {
        self == .golden ? 1 : 0
    }

    public var emoji: String {
        switch self {
        case .fumbled: return "🫧"
        case .steady: return "🍲"
        case .golden: return "✨"
        }
    }
}

/// 마무리 미니게임을 마친 뒤 남는 기록. 요리 결과 카드에 그대로 붙는다.
public struct SimmerOutcome: Sendable, Equatable {
    public let score: Int
    public let maxScore: Int
    public let grade: SimmerGrade
    public let hits: Int
    public let goldens: Int
    public let misses: Int
    public let fumbles: Int

    public init(score: Int,
                maxScore: Int,
                grade: SimmerGrade,
                hits: Int,
                goldens: Int,
                misses: Int,
                fumbles: Int) {
        self.score = score
        self.maxScore = max(1, maxScore)
        self.grade = grade
        self.hits = hits
        self.goldens = goldens
        self.misses = misses
        self.fumbles = fumbles
    }

    public var rating: Double {
        min(1, max(0, Double(score) / Double(maxScore)))
    }

    public var message: String {
        "\(grade.emoji) 마무리 \(score)/\(maxScore) · \(grade.title)"
    }

    public var summaryLine: String {
        "황금 \(goldens) · 성공 \(hits) · 놓침 \(misses) · 헛손 \(fumbles)"
    }
}

/// 「솥단지 불 조절 타이밍」 미니게임.
///
/// 온도 바 위의 바늘이 오르내리고, 부탁마다 황금 구간이 하나씩 정해진다.
/// 부탁이 열린 사이에 **맞는 손짓**을 **황금 구간 안에서** 누르면 점수가 쌓인다.
/// 다섯 번의 부탁을 모두 처리하면 성적이 나오고, 성적이 좋으면 완성도가 한 단계 오르거나
/// 한 접시가 더 나온다. 시드를 고정하면 같은 순서로 재현된다.
public struct SimmerMinigame: Sendable, Equatable {
    public static let duration: Double = 12.0
    public static let requestCount = 5
    /// 바늘이 1초에 움직이는 비율.
    public static let needleSpeed: Double = 0.58
    /// 황금 구간의 폭(0~1 바 기준).
    public static let bandWidth: Double = 0.26
    /// 구간 안에서도 가운데 이 비율만큼이 '황금빛'.
    public static let goldenShare: Double = 0.5
    public static let hitPoints = 20
    public static let goldenPoints = 30
    public static let fumblePenalty = 5
    /// 최고점 대비 이 비율을 넘으면 황금빛 온기.
    public static let goldenThreshold: Double = 0.7
    /// 이 비율을 넘으면 고른 온기.
    public static let steadyThreshold: Double = 0.33

    public let seed: UInt64
    public private(set) var elapsed: Double = 0
    public private(set) var needle: Double = 0
    public private(set) var direction: Double = 1
    public private(set) var requests: [SimmerRequest]
    public private(set) var index: Int = 0
    public private(set) var score: Int = 0
    public private(set) var hits: Int = 0
    public private(set) var goldens: Int = 0
    public private(set) var misses: Int = 0
    public private(set) var fumbles: Int = 0
    public private(set) var lastPress: SimmerPressResult = .ignored

    public init(seed: UInt64, duration: Double = SimmerMinigame.duration) {
        self.seed = seed
        self.requests = SimmerMinigame.makeRequests(seed: seed, duration: max(6, duration))
    }

    static func makeRequests(seed: UInt64, duration: Double) -> [SimmerRequest] {
        var rng = SeededRandom(seed: seed)
        let slot = duration / Double(requestCount)
        var list: [SimmerRequest] = []
        for index in 0..<requestCount {
            let opensAt = Double(index) * slot + 0.15
            let closesAt = Double(index + 1) * slot - 0.10
            let maxStart = max(0.02, 1 - bandWidth - 0.02)
            let bandStart = Double.random(in: 0.02...maxStart, using: &rng)
            let action: SimmerAction = Double.random(in: 0..<1, using: &rng) < 0.5 ? .lowerHeat : .stirWooden
            list.append(SimmerRequest(
                id: index,
                action: action,
                bandStart: bandStart,
                bandEnd: min(1, bandStart + bandWidth),
                opensAt: opensAt,
                closesAt: closesAt
            ))
        }
        return list
    }

    // MARK: - 진행

    public var isFinished: Bool { elapsed >= Self.duration }

    public var progress: Double { min(1, elapsed / Self.duration) }

    public var remaining: Double { max(0, Self.duration - elapsed) }

    public var maxScore: Int { Self.requestCount * Self.goldenPoints }

    /// 지금 부탁. 모두 처리했으면 nil.
    public var currentRequest: SimmerRequest? {
        guard index < requests.count else { return nil }
        return requests[index]
    }

    /// 지금 손짓을 받을 수 있는 상태인가.
    public var isAwaitingPress: Bool {
        guard let request = currentRequest, !isFinished else { return false }
        return elapsed >= request.opensAt && elapsed <= request.closesAt
    }

    public mutating func tick(_ delta: Double) {
        guard !isFinished, delta > 0 else { return }
        let step = min(delta, Self.duration - elapsed)

        var next = needle + direction * Self.needleSpeed * step
        var bounces = 0
        while (next > 1 || next < 0) && bounces < 8 {
            if next > 1 {
                next = 2 - next
                direction = -1
            } else if next < 0 {
                next = -next
                direction = 1
            }
            bounces += 1
        }
        needle = min(1, max(0, next))
        elapsed = min(Self.duration, elapsed + step)

        // 시간이 지나 닫힌 부탁은 놓친 것으로 센다.
        while index < requests.count && elapsed > requests[index].closesAt {
            misses += 1
            index += 1
        }
    }

    public mutating func press(_ action: SimmerAction) -> SimmerPressResult {
        guard !isFinished, let request = currentRequest else {
            lastPress = .ignored
            return .ignored
        }
        guard elapsed >= request.opensAt, elapsed <= request.closesAt else {
            lastPress = .ignored
            return .ignored
        }
        guard action == request.action else {
            fumbles += 1
            score = max(0, score - Self.fumblePenalty)
            let expected = request.action == .lowerHeat ? "지금은 불을 낮출 때예요" : "지금은 저어야 해요"
            lastPress = .fumble(reason: expected)
            return lastPress
        }
        guard request.contains(needle) else {
            fumbles += 1
            score = max(0, score - Self.fumblePenalty)
            lastPress = .fumble(reason: "황금 구간을 놓쳤어요. 바늘이 초록 구간에 올 때 눌러 주세요")
            return lastPress
        }

        let golden = request.isGolden(needle)
        let points = golden ? Self.goldenPoints : Self.hitPoints
        score += points
        hits += 1
        if golden { goldens += 1 }
        index += 1
        lastPress = .hit(points: points, golden: golden)
        return lastPress
    }

    /// 지금 성적으로 나올 등급.
    public var grade: SimmerGrade {
        let ratio = Double(score) / Double(maxScore)
        if ratio >= Self.goldenThreshold { return .golden }
        if ratio >= Self.steadyThreshold { return .steady }
        return .fumbled
    }

    public func outcome() -> SimmerOutcome {
        SimmerOutcome(
            score: score,
            maxScore: maxScore,
            grade: grade,
            hits: hits,
            goldens: goldens,
            misses: misses,
            fumbles: fumbles
        )
    }
}
