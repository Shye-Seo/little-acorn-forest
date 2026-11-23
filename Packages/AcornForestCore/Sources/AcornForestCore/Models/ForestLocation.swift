import Foundation

/// 숲 지도에서 움직일 수 있는 장소.
public enum ForestLocation: String, CaseIterable, Codable, Identifiable, Sendable {
    case cabinKitchen
    case berryPatch
    case fireflyPond
    case owlLibrary
    case festivalGlade

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cabinKitchen: return "오두막 부엌"
        case .berryPatch: return "이슬방울 덤불"
        case .fireflyPond: return "반딧불이 연못"
        case .owlLibrary: return "몽의 서재"
        case .festivalGlade: return "별빛 축제터"
        }
    }

    public var blurb: String {
        switch self {
        case .cabinKitchen:
            return "할머니의 솥단지와 낡은 레시피 수첩이 그대로 남아 있다."
        case .berryPatch:
            return "해가 뜨기 전에만 이슬이 맺히는 덤불. 베리가 손끝에서 톡 터진다."
        case .fireflyPond:
            return "밤이 되면 연못 위로 반딧불이가 내려앉는다."
        case .owlLibrary:
            return "책 냄새와 촛농 냄새가 섞인 곳. 몽이 밤새 여기 있다."
        case .festivalGlade:
            return "이웃들이 모여 별빛 축제를 여는 빈터."
        }
    }

    /// 이곳에서 떨어지는 재료 후보(많이 적을수록 자주 나온다).
    public var ingredientPool: [Ingredient] {
        switch self {
        case .cabinKitchen: return [.dewberry, .fireflyNectar, .starMossShroom]
        case .berryPatch: return [.dewberry, .dewberry, .moonflakeSpice]
        case .fireflyPond: return [.fireflyNectar, .fireflyNectar, .dewberry]
        case .owlLibrary: return [.moonflakeSpice, .moonflakeSpice, .starMossShroom]
        case .festivalGlade: return [.dewberry, .fireflyNectar, .starMossShroom, .moonflakeSpice]
        }
    }

    /// 재료가 떨어지는 간격(초).
    public var spawnInterval: ClosedRange<Double> {
        switch self {
        case .cabinKitchen: return 1.15...1.55
        case .berryPatch: return 0.95...1.35
        case .fireflyPond: return 1.05...1.45
        case .owlLibrary: return 1.25...1.70
        case .festivalGlade: return 0.85...1.20
        }
    }

    /// 위에서 아래까지 떨어지는 데 걸리는 시간(초).
    public var fallDuration: ClosedRange<Double> {
        switch self {
        case .cabinKitchen: return 2.1...2.6
        case .berryPatch: return 1.8...2.3
        case .fireflyPond: return 2.0...2.5
        case .owlLibrary: return 2.3...2.8
        case .festivalGlade: return 1.6...2.1
        }
    }

    public var isGatherable: Bool {
        switch self {
        case .cabinKitchen, .festivalGlade: return true
        case .berryPatch, .fireflyPond, .owlLibrary: return true
        }
    }

    /// 이 장소가 열리는 이야기 지점.
    public var unlockChapter: StoryChapter {
        switch self {
        case .cabinKitchen: return .prologue
        case .berryPatch, .fireflyPond, .owlLibrary: return .chapterOne
        case .festivalGlade: return .epilogue
        }
    }

    /// 지도 위에서의 대략적인 위치(0~1 비율). UI가 그대로 쓴다.
    public var mapAnchor: (x: Double, y: Double) {
        switch self {
        case .cabinKitchen: return (0.28, 0.30)
        case .berryPatch: return (0.70, 0.24)
        case .fireflyPond: return (0.76, 0.60)
        case .owlLibrary: return (0.44, 0.58)
        case .festivalGlade: return (0.46, 0.86)
        }
    }
}
