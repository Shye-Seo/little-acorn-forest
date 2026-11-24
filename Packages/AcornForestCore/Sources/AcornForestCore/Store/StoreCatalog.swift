import Foundation

/// 앱 안에서 실제로 열리는 유료 확장 콘텐츠 묶음.
/// 결제는 StoreKit 2(`StoreManager`)가 맡고, 게임 규칙은 이 열거형만 안다.
public enum ContentPack: String, CaseIterable, Codable, Identifiable, Sendable {
    case greenhouse
    case bottleWorkshop
    case asmrTracks

    public var id: String { rawValue }

    /// App Store Connect에 등록하는 상품 id. `Products.storekit`과 반드시 같아야 한다.
    public var productID: String {
        switch self {
        case .greenhouse: return "com.quoguri.moonlightjamjar.greenhouse"
        case .bottleWorkshop: return "com.quoguri.moonlightjamjar.bottleskins"
        case .asmrTracks: return "com.quoguri.moonlightjamjar.asmrpack"
        }
    }

    public var displayName: String {
        switch self {
        case .greenhouse: return "사계절 온실 확장팩"
        case .bottleWorkshop: return "빈티지 병 공방 스킨"
        case .asmrTracks: return "모닥불 ASMR 트랙 팩"
        }
    }

    /// 가격(원). `Products.storekit`의 표시 가격과 같은 값이다.
    public var priceKRW: Int {
        switch self {
        case .greenhouse: return 4400
        case .bottleWorkshop: return 2500
        case .asmrTracks: return 1900
        }
    }

    public var priceLine: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        let number = formatter.string(from: NSNumber(value: priceKRW)) ?? "\(priceKRW)"
        return "₩\(number)"
    }

    public var tagline: String {
        switch self {
        case .greenhouse:
            return "에필로그 뒤에 열리는 유리 지붕 온실과, 그 안의 두 계절 친구"
        case .bottleWorkshop:
            return "선반에 놓인 병과 오두막 벽지·조명을 바꾸는 스킨"
        case .asmrTracks:
            return "모닥불 집중 타이머에 밤벌레와 풍경소리를 더하고, 보상을 두 배로"
        }
    }

    /// 상점 카드에 줄줄이 보여 줄 실제 내용.
    public var contents: [String] {
        switch self {
        case .greenhouse:
            return [
                "사계절 온실 장소 (봄·여름·가을·겨울 네 칸)",
                "신규 레시피 3종 · 봄 벚꽃꿀 잼 / 가을 단풍 콩포트 / 겨울 눈꽃 잼",
                "신규 재료 3종 · 봄 벚꽃꿀 / 가을 단풍 수액 / 겨울 눈꽃",
                "신규 이웃 2명 · 사슴 루나, 수달 코코 (대화·호감도·소원 포함)"
            ]
        case .bottleWorkshop:
            return [
                "병 스킨 · 크리스탈 병",
                "마개 스킨 · 별 모양 마개",
                "오두막 스킨 3종 · 다락 등불 / 별빛 벽지 / 이끼 램프",
                "선반과 집중 타이머 배경에 바로 반영"
            ]
        case .asmrTracks:
            return [
                "ASMR 트랙 추가 · 밤벌레 / 풍경소리",
                "집중 타이머 완료 보상 2배 (반딧불이 가루·재료)",
                "타이머 화면의 밤 풍경 연출 추가"
            ]
        }
    }

    public var emoji: String {
        switch self {
        case .greenhouse: return "🌿"
        case .bottleWorkshop: return "🏺"
        case .asmrTracks: return "🔥"
        }
    }
}

/// 상점에 진열되는 상품 순서와 조회.
public enum StoreCatalog {
    public static var all: [ContentPack] { ContentPack.allCases }

    public static var productIDs: [String] { all.map(\.productID) }

    public static func pack(forProductID id: String) -> ContentPack? {
        all.first { $0.productID == id }
    }

    public static var totalPriceKRW: Int {
        all.reduce(0) { $0 + $1.priceKRW }
    }

    public static func isKnownProductID(_ id: String) -> Bool {
        pack(forProductID: id) != nil
    }
}
