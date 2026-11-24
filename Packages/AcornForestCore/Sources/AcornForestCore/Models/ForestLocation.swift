import Foundation

/// 숲 지도에서 움직일 수 있는 장소.
public enum ForestLocation: String, CaseIterable, Codable, Identifiable, Sendable {
    case cabinKitchen
    case berryPatch
    case fireflyPond
    case owlLibrary
    case festivalGlade
    case moonlitGarden
    case greenhouse

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cabinKitchen: return "오두막 부엌"
        case .berryPatch: return "이슬방울 덤불"
        case .fireflyPond: return "반딧불이 연못"
        case .owlLibrary: return "몽의 서재"
        case .festivalGlade: return "별빛 축제터"
        case .moonlitGarden: return "달빛 비밀 정원"
        case .greenhouse: return "사계절 온실"
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
        case .moonlitGarden:
            return "보름달이 뜨는 밤에만 담장 사이로 길이 열리는 정원. 잎맥을 따라 월광 이슬이 흐른다."
        case .greenhouse:
            return "에필로그 뒤에야 열리는 유리 지붕의 온실. 봄·여름·가을·겨울이 네 칸에 나란히 자란다."
        }
    }

    /// 이곳에서 떨어지는 재료와 무게. 합이 100이면 그대로 %로 읽힌다.
    /// 등급 비율은 `GatherBalance`가 정한 값을 그대로 따른다
    /// (희귀 재료가 있는 곳 68·22·10 / 없는 곳 78·22).
    public var dropTable: [GatherDrop] {
        switch self {
        case .cabinKitchen:
            return [GatherDrop(.dewberry, 48), GatherDrop(.fireflyNectar, 30), GatherDrop(.moonflakeSpice, 22)]
        case .berryPatch:
            return [GatherDrop(.dewberry, 56), GatherDrop(.starMossShroom, 22), GatherDrop(.moonflakeSpice, 22)]
        case .fireflyPond:
            return [GatherDrop(.fireflyNectar, 50), GatherDrop(.dewberry, 28), GatherDrop(.moonflakeSpice, 22)]
        case .owlLibrary:
            return [GatherDrop(.starMossShroom, 46), GatherDrop(.dewberry, 20), GatherDrop(.fireflyNectar, 12), GatherDrop(.moonflakeSpice, 22)]
        case .festivalGlade:
            return [GatherDrop(.dewberry, 30), GatherDrop(.fireflyNectar, 26), GatherDrop(.starMossShroom, 22), GatherDrop(.moonflakeSpice, 22)]
        case .moonlitGarden:
            return [GatherDrop(.dewberry, 34), GatherDrop(.starMossShroom, 34), GatherDrop(.moonflakeSpice, 22), GatherDrop(.moonlitDew, 10)]
        case .greenhouse:
            return [GatherDrop(.dewberry, 68), GatherDrop(.cherryHoney, 11), GatherDrop(.mapleSap, 11), GatherDrop(.snowBlossom, 10)]
        }
    }

    /// 이곳에서 나올 수 있는 재료만 모은 목록(무게 무시).
    public var ingredientPool: [Ingredient] {
        dropTable.map(\.ingredient)
    }

    /// 재료가 떨어지는 간격(초). 길게 잡을수록 한 판에 줍는 양이 줄어든다.
    public var spawnInterval: ClosedRange<Double> {
        switch self {
        case .cabinKitchen: return 1.45...1.95
        case .berryPatch: return 1.30...1.75
        case .fireflyPond: return 1.35...1.80
        case .owlLibrary: return 1.50...2.00
        case .festivalGlade: return 1.20...1.65
        case .moonlitGarden: return 1.30...1.75
        case .greenhouse: return 1.30...1.80
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
        case .moonlitGarden: return 1.9...2.4
        case .greenhouse: return 1.9...2.5
        }
    }

    public var isGatherable: Bool {
        switch self {
        case .cabinKitchen, .festivalGlade: return true
        case .berryPatch, .fireflyPond, .owlLibrary: return true
        case .moonlitGarden, .greenhouse: return true
        }
    }

    /// 이 장소가 열리는 이야기 지점.
    public var unlockChapter: StoryChapter {
        switch self {
        case .cabinKitchen: return .prologue
        case .berryPatch, .fireflyPond, .owlLibrary: return .chapterOne
        case .festivalGlade: return .epilogue
        case .moonlitGarden: return .chapterOne
        case .greenhouse: return .epilogue
        }
    }

    /// 이 장소가 확장팩으로 열리는지. 없으면 무료 지역이다.
    public var requiredPack: ContentPack? {
        switch self {
        case .greenhouse: return .greenhouse
        case .cabinKitchen, .berryPatch, .fireflyPond, .owlLibrary, .festivalGlade, .moonlitGarden:
            return nil
        }
    }

    /// 보름달 밤에만 길이 열리는 장소인지.
    public var requiresFullMoon: Bool {
        self == .moonlitGarden
    }

    /// 지도 위에서의 대략적인 위치(0~1 비율). UI가 그대로 쓴다.
    public var mapAnchor: (x: Double, y: Double) {
        switch self {
        case .cabinKitchen: return (0.26, 0.24)
        case .berryPatch: return (0.70, 0.20)
        case .fireflyPond: return (0.82, 0.46)
        case .owlLibrary: return (0.44, 0.50)
        case .festivalGlade: return (0.50, 0.82)
        case .moonlitGarden: return (0.13, 0.52)
        case .greenhouse: return (0.86, 0.82)
        }
    }
}
