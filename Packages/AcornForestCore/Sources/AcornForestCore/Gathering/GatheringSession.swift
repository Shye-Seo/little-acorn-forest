import Foundation

/// 테스트와 재현을 위해 시드를 고정할 수 있는 난수 생성기(SplitMix64).
public struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 하늘에서 떨어지는 재료 하나.
public struct GatherItem: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let lane: Int
    public let ingredient: Ingredient
    public let catchTime: Double
    public let fallDuration: Double
    public let isGolden: Bool
    public var isCaught: Bool
    public var isMissed: Bool

    public init(id: Int,
                lane: Int,
                ingredient: Ingredient,
                catchTime: Double,
                fallDuration: Double,
                isGolden: Bool = false,
                isCaught: Bool = false,
                isMissed: Bool = false) {
        self.id = id
        self.lane = lane
        self.ingredient = ingredient
        self.catchTime = catchTime
        self.fallDuration = fallDuration
        self.isGolden = isGolden
        self.isCaught = isCaught
        self.isMissed = isMissed
    }

    /// 화면에 나타나는 시각.
    public var spawnTime: Double { max(0, catchTime - fallDuration) }

    public var isResolved: Bool { isCaught || isMissed }
}

public enum TapResult: Sendable, Equatable {
    case caught(Ingredient, points: Int, golden: Bool)
    case nothing

    public var message: String {
        switch self {
        case .caught(let ingredient, let points, let golden):
            return golden ? "반짝! \(ingredient.title) +\(points)" : "\(ingredient.title) +\(points)"
        case .nothing:
            return "바구니가 텅 비었어요"
        }
    }
}

public struct GatheringSummary: Sendable, Equatable {
    public let location: ForestLocation
    public let score: Int
    public let bestStreak: Int
    public let caughtCount: Int
    public let missedCount: Int
    public let harvest: [ItemStack]
    public let bonus: [ItemStack]

    public init(location: ForestLocation,
                score: Int,
                bestStreak: Int,
                caughtCount: Int,
                missedCount: Int,
                harvest: [ItemStack],
                bonus: [ItemStack]) {
        self.location = location
        self.score = score
        self.bestStreak = bestStreak
        self.caughtCount = caughtCount
        self.missedCount = missedCount
        self.harvest = harvest
        self.bonus = bonus
    }

    public var accuracy: Double {
        let total = caughtCount + missedCount
        return total > 0 ? Double(caughtCount) / Double(total) : 0
    }

    public var headline: String {
        if score >= 120 { return "바구니가 넘칠 만큼 주웠어요" }
        if score >= 70 { return "오늘 숲은 후했어요" }
        if caughtCount > 0 { return "작은 바구니 하나는 채웠어요" }
        return "바구니가 비었어요. 다시 해 볼까요?"
    }
}

/// 숲속 채집 미니게임의 상태 머신.
/// 3개의 길로 재료가 떨어지고, 도착 지점에서 ±catchWindow 안에 누르면 바구니에 담긴다.
public struct GatheringSession: Sendable {
    public static let laneCount = 3
    public static let defaultDuration: Double = 26.0
    public static let defaultCatchWindow: Double = 0.24
    public static let missPenalty = 3
    public static let streakStep = 0.1
    public static let streakCap = 10

    public let location: ForestLocation
    public let duration: Double
    public let catchWindow: Double
    public let seed: UInt64

    public private(set) var elapsed: Double = 0
    public private(set) var items: [GatherItem] = []
    public private(set) var score: Int = 0
    public private(set) var streak: Int = 0
    public private(set) var bestStreak: Int = 0
    public private(set) var missedCount: Int = 0
    public private(set) var tapCount: Int = 0

    public init(location: ForestLocation,
                seed: UInt64,
                duration: Double = GatheringSession.defaultDuration,
                catchWindow: Double = GatheringSession.defaultCatchWindow) {
        self.location = location
        self.duration = max(6, duration)
        self.catchWindow = max(0.05, catchWindow)
        self.seed = seed
        self.items = GatheringSession.makeItems(
            location: location,
            seed: seed,
            duration: self.duration
        )
    }

    static func makeItems(location: ForestLocation, seed: UInt64, duration: Double) -> [GatherItem] {
        var rng = SeededRandom(seed: seed)
        let pool = location.ingredientPool
        var list: [GatherItem] = []
        var time = 0.8
        var id = 0

        while time < duration - 0.5 {
            let fall = Double.random(in: location.fallDuration, using: &rng)
            let lane = Int.random(in: 0..<GatheringSession.laneCount, using: &rng)
            let ingredient = pool[Int.random(in: 0..<pool.count, using: &rng)]
            let goldenRoll = Double.random(in: 0..<1, using: &rng)
            let catchTime = min(duration - 0.35, time + fall)
            list.append(GatherItem(
                id: id,
                lane: lane,
                ingredient: ingredient,
                catchTime: catchTime,
                fallDuration: fall,
                isGolden: goldenRoll < 0.12
            ))
            id += 1
            let gap = Double.random(in: location.spawnInterval, using: &rng)
            time += gap
        }

        return list
    }

    // MARK: - 진행

    public var isFinished: Bool { elapsed >= duration }

    public var progress: Double { min(1, elapsed / duration) }

    public var remaining: Double { max(0, duration - elapsed) }

    public var isAlmostOver: Bool { remaining <= 5 }

    public var caughtItems: [GatherItem] { items.filter(\.isCaught) }

    public var caughtCount: Int { items.filter { $0.isCaught }.count }

    public var accuracy: Double {
        let resolved = caughtCount + missedCount
        return resolved > 0 ? Double(caughtCount) / Double(resolved) : 0
    }

    public var comboMultiplier: Double {
        1 + Double(min(streak, Self.streakCap)) * Self.streakStep
    }

    public var harvest: [ItemStack] {
        var counts: [Ingredient: Int] = [:]
        for item in caughtItems {
            counts[item.ingredient, default: 0] += 1
        }
        return Ingredient.allCases.compactMap { ingredient in
            guard let count = counts[ingredient], count > 0 else { return nil }
            return ItemStack(ingredient, count)
        }
    }

    /// 연속 채집·많이 담기 보너스.
    public var bonusHarvest: [ItemStack] {
        var bonus: [ItemStack] = []
        if bestStreak >= 6 {
            bonus.append(ItemStack(.moonflakeSpice, 1))
        }
        if caughtCount >= 8 {
            bonus.append(ItemStack(.fireflyNectar, 1))
        }
        return bonus
    }

    public mutating func tick(_ delta: Double) {
        guard !isFinished, delta > 0 else { return }
        elapsed = min(duration, elapsed + delta)

        for index in items.indices {
            guard !items[index].isResolved else { continue }
            if elapsed > items[index].catchTime + catchWindow {
                items[index].isMissed = true
                missedCount += 1
                streak = 0
                score = max(0, score - Self.missPenalty)
            }
        }
    }

    /// 지정한 길에서 지금 담을 수 있는 가장 가까운 재료를 잡는다.
    public mutating func tap(lane: Int) -> TapResult {
        guard !isFinished, lane >= 0, lane < Self.laneCount else { return .nothing }
        tapCount += 1

        var bestIndex: Int?
        var bestDistance = Double.greatestFiniteMagnitude
        for index in items.indices {
            let item = items[index]
            guard item.lane == lane, !item.isResolved else { continue }
            let distance = abs(elapsed - item.catchTime)
            guard distance <= catchWindow else { continue }
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }

        guard let index = bestIndex else { return .nothing }

        items[index].isCaught = true
        let item = items[index]
        let multiplier = comboMultiplier
        let base = item.ingredient.gatherPoints * (item.isGolden ? 2 : 1)
        let points = Int((Double(base) * multiplier).rounded())
        score += points
        streak += 1
        bestStreak = max(bestStreak, streak)
        return .caught(item.ingredient, points: points, golden: item.isGolden)
    }

    public func summary() -> GatheringSummary {
        GatheringSummary(
            location: location,
            score: score,
            bestStreak: bestStreak,
            caughtCount: caughtCount,
            missedCount: missedCount,
            harvest: harvest,
            bonus: bonusHarvest
        )
    }

    /// 화면 그리기에 쓰는 위치(0 위 ~ 1 아래). 아직 나타나지 않은 재료는 음수.
    public func fallProgress(of item: GatherItem) -> Double {
        guard item.fallDuration > 0 else { return 1 }
        return (elapsed - item.spawnTime) / item.fallDuration
    }

    public func isVisible(_ item: GatherItem) -> Bool {
        !item.isResolved && fallProgress(of: item) >= 0
    }
}
