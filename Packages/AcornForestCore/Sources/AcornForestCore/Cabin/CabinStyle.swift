import Foundation

/// 오두막 벽지와 조명 스킨. 병 공방 스킨에서 열린다.
public enum CabinStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case attic
    case starWall
    case mossLamp

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .attic: return "다락 등불"
        case .starWall: return "별빛 벽지"
        case .mossLamp: return "이끼 램프"
        }
    }

    public var note: String {
        switch self {
        case .attic: return "할머니 때부터 쓰던 벽지와 등잔. 선반 위 유리만 반짝인다."
        case .starWall: return "벽 전체가 옅은 별가루로 덮인다. 밤에는 벽이 조금씩 밝아진다."
        case .mossLamp: return "이끼를 넣은 램프가 초록빛을 낸다. 비 오는 날처럼 방이 조용해진다."
        }
    }

    /// 벽 색(0xRRGGBB). 화면에서 Color(hex:)로 쓴다.
    public var wallHex: UInt32 {
        switch self {
        case .attic: return 0xF3E7D3
        case .starWall: return 0xDDD6EA
        case .mossLamp: return 0xE3E8DA
        }
    }

    public var lampHex: UInt32 {
        switch self {
        case .attic: return 0xF2DFAF
        case .starWall: return 0xB3A3D4
        case .mossLamp: return 0xA8BDA3
        }
    }

    public var requiredPack: ContentPack? {
        self == .attic ? nil : .bottleWorkshop
    }

    public static func styles(ownsWorkshop: Bool) -> [CabinStyle] {
        allCases.filter { style in
            guard let pack = style.requiredPack else { return true }
            return ownsWorkshop && pack == .bottleWorkshop
        }
    }

    public static func isUnlocked(_ style: CabinStyle, ownsWorkshop: Bool) -> Bool {
        guard let pack = style.requiredPack else { return true }
        return ownsWorkshop && pack == .bottleWorkshop
    }
}
