import Foundation

/// 잼 병의 모양. 앞의 세 가지는 무료, 크리스탈 병은 병 공방 스킨에서 열린다.
public enum JarBottleStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case roundGlass
    case starVial
    case gourd
    case crystal

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .roundGlass: return "둥근 유리병"
        case .starVial: return "별빛 각병"
        case .gourd: return "호리병"
        case .crystal: return "크리스탈 병"
        }
    }

    public var note: String {
        switch self {
        case .roundGlass: return "할머니가 쓰던 그 병. 손때가 유리 안쪽에 옅게 배어 있다."
        case .starVial: return "모서리가 여섯 개인 각진 병. 빛을 받으면 별처럼 갈라진다."
        case .gourd: return "허리가 잘록한 병. 잼이 아래로 천천히 내려앉는다."
        case .crystal: return "공방에서 갈고 닦은 크리스탈. 뚜껑을 열면 잼 색이 벽에 비친다."
        }
    }

    public var requiredPack: ContentPack? {
        self == .crystal ? .bottleWorkshop : nil
    }

    public var emoji: String {
        switch self {
        case .roundGlass: return "🫙"
        case .starVial: return "⭐"
        case .gourd: return "🍶"
        case .crystal: return "💎"
        }
    }
}

/// 병뚜껑. 별 모양 마개는 병 공방 스킨에서 열린다.
public enum JarCapStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case cork
    case moonlightMetal
    case checkCloth
    case starCap

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cork: return "코르크 마개"
        case .moonlightMetal: return "달빛 금속 마개"
        case .checkCloth: return "체크 천 마개"
        case .starCap: return "별 모양 마개"
        }
    }

    public var note: String {
        switch self {
        case .cork: return "열 때마다 작게 ‘뽁’ 소리가 난다."
        case .moonlightMetal: return "차갑지만 손에 쥐면 금세 따뜻해진다."
        case .checkCloth: return "할머니가 남긴 체크무늬 손수건을 잘라 덮었다."
        case .starCap: return "다섯 갈래가 고르게 접혀 있다. 닫으면 별이 잠깐 반짝인다."
        }
    }

    public var requiredPack: ContentPack? {
        self == .starCap ? .bottleWorkshop : nil
    }
}

/// 병에 묶는 리본 색.
public enum JarRibbonColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case sage
    case terracotta
    case butter
    case dew
    case moonflake
    case berry

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sage: return "이끼 초록"
        case .terracotta: return "흙빛 주황"
        case .butter: return "버터 노랑"
        case .dew: return "이슬 파랑"
        case .moonflake: return "달조각 보라"
        case .berry: return "베리 분홍"
        }
    }

    public var hex: UInt32 {
        switch self {
        case .sage: return 0x5D7A58
        case .terracotta: return 0xC97B5D
        case .butter: return 0xF2DFAF
        case .dew: return 0x7FA6C9
        case .moonflake: return 0xB3A3D4
        case .berry: return 0xC96A78
        }
    }
}

/// 병 공방 스킨 보유 여부에 따라 고를 수 있는 목록.
public enum JarStyleCatalog {
    public static let defaultBottle: JarBottleStyle = .roundGlass
    public static let defaultCap: JarCapStyle = .cork
    public static let defaultRibbon: JarRibbonColor = .sage

    public static func bottles(ownsWorkshop: Bool) -> [JarBottleStyle] {
        JarBottleStyle.allCases.filter { isUnlocked($0, ownsWorkshop: ownsWorkshop) }
    }

    public static func caps(ownsWorkshop: Bool) -> [JarCapStyle] {
        JarCapStyle.allCases.filter { isUnlocked($0, ownsWorkshop: ownsWorkshop) }
    }

    public static func isUnlocked(_ bottle: JarBottleStyle, ownsWorkshop: Bool) -> Bool {
        guard let pack = bottle.requiredPack else { return true }
        return ownsWorkshop && pack == .bottleWorkshop
    }

    public static func isUnlocked(_ cap: JarCapStyle, ownsWorkshop: Bool) -> Bool {
        guard let pack = cap.requiredPack else { return true }
        return ownsWorkshop && pack == .bottleWorkshop
    }

    public static var lockedStyleCount: Int {
        JarBottleStyle.allCases.filter { $0.requiredPack != nil }.count
            + JarCapStyle.allCases.filter { $0.requiredPack != nil }.count
    }
}
