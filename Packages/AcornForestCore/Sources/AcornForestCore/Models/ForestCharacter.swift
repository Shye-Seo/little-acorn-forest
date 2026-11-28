import Foundation

/// 숲에 사는 이웃들. 주인공 '보리'는 이 목록 밖의 화자로 다룬다.
/// 앞의 네 명은 프롤로그부터 만나는 숲의 이웃이고,
/// 그 다음 두 명은 사계절 온실 확장팩에서 처음 만나는 온실지기,
/// 마지막 두 명은 이야기를 마친 뒤 심야 구역에 찾아오는 방문 손님이다.
public enum CharacterID: String, CaseIterable, Codable, Identifiable, Sendable {
    case tori
    case songi
    case mong
    case rubi
    case luna
    case coco
    case dallae
    case moru

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .tori: return "토리"
        case .songi: return "송이"
        case .mong: return "몽"
        case .rubi: return "루비"
        case .luna: return "루나"
        case .coco: return "코코"
        case .dallae: return "달래"
        case .moru: return "모루"
        }
    }

    public var species: String {
        switch self {
        case .tori: return "다람쥐"
        case .songi: return "고슴도치"
        case .mong: return "올빼미"
        case .rubi: return "여우"
        case .luna: return "사슴"
        case .coco: return "수달"
        case .dallae: return "종달새"
        case .moru: return "두더지"
        }
    }

    public var personality: String {
        switch self {
        case .tori:
            return "아침부터 저녁까지 부지런하다. 말이 많고 셈이 빠르지만, 남의 바구니가 비면 자기 이슬방울 베리를 먼저 내민다."
        case .songi:
            return "낯을 많이 가려서 말을 걸면 잎 뒤에 숨는다. 대신 자기 정원의 별이끼 버섯 이름은 전부 외우고 있다."
        case .mong:
            return "밤에만 눈을 뜨는 서재지기. 감정을 말로 잘 하지 않아서, 다정함은 늘 책갈피에 끼워 두고 산다."
        case .rubi:
            return "숲에서 제일 수다스럽다. 소문을 옮기는 걸 좋아하지만, 정작 어려운 이웃의 이야기는 함부로 꺼내지 않는다."
        case .luna:
            return "유리 지붕 아래에서 계절을 옮겨 심는 사슴. 말수는 적지만 밤에 별을 세는 일만은 끝까지 해 둔다."
        case .coco:
            return "온실 연못에서 조약돌을 굴리며 사는 수달. 손이 빠르고 웃음이 잦아서, 온실의 물소리가 코코 소리처럼 들릴 때가 있다."
        case .dallae:
            return "심야에만 다리 위에 내려앉는 종달새 손님. 낮에는 어디 있는지 아무도 모르고, 밤이 되면 자기 노래를 처음부터 끝까지 들려준다. 듣는 사람이 없어도 노래는 줄이지 않는다."
        case .moru:
            return "우편 자루를 메고 숲과 다리 사이를 오가는 두더지. 길을 잃은 밤손님을 다리 끝까지 데려다주는 게 일이다. 자기가 무슨 일을 했는지는 잘 말하지 않는다."
        }
    }

    public var favoriteRecipeID: String {
        switch self {
        case .tori: return "meteor-berry-compote"
        case .songi: return "moonshadow-herb-jelly"
        case .mong: return "starlight-mist-jam"
        case .rubi: return "firefly-sparkle-jam"
        case .luna: return "winter-snow-jam"
        case .coco: return "spring-blossom-honey-jam"
        case .dallae: return "midnight-starlight-marmalade"
        case .moru: return "star-salt-berry-glass-jam"
        }
    }

    public var likedRecipeIDs: [String] {
        switch self {
        case .tori: return ["firefly-sparkle-jam", "golden-fullmoon-jam"]
        case .songi: return ["meteor-berry-compote", "starlight-mist-jam"]
        case .mong: return ["dawn-dew-jam"]
        case .rubi: return ["cloud-cotton-marmalade", "meadow-sparkle-jam"]
        case .luna: return ["spring-blossom-honey-jam", "autumn-maple-compote"]
        case .coco: return ["autumn-maple-compote", "winter-snow-jam"]
        case .dallae: return ["midnight-bell-cotton-jam", "comet-trail-compote"]
        case .moru: return ["star-salt-ember-jam", "moth-nectar-jam"]
        }
    }

    public var dislikedRecipeIDs: [String] {
        switch self {
        case .tori: return ["moonshadow-herb-jelly"]
        case .songi: return ["firefly-sparkle-jam"]
        case .mong: return ["meteor-berry-compote"]
        case .rubi: return ["dawn-dew-jam"]
        case .luna: return ["firefly-sparkle-jam"]
        case .coco: return ["moonshadow-herb-jelly"]
        case .dallae: return ["moth-lantern-jam"]
        case .moru: return ["comet-frost-jam"]
        }
    }

    /// 이웃마다 숲의 별빛 축제에 걸고 있는 소원.
    public var wish: String {
        switch self {
        case .tori:
            return "잔뜩 모은 베리로 콩포트를 끓여 누군가와 나눠 먹는 저녁"
        case .songi:
            return "정원에 이름을 붙여 주는 사람"
        case .mong:
            return "서재 창문으로 별이 한 번 더 들어오는 밤"
        case .rubi:
            return "숲 전체가 같이 웃는 노래"
        case .luna:
            return "겨울에도 얼지 않는 화분 하나"
        case .coco:
            return "봄이 오는 날을 누군가와 같이 세는 것"
        case .dallae:
            return "누군가 자기 노래를 마지막 소절까지 들어 주는 새벽"
        case .moru:
            return "길 잃은 밤손님이 다리 끝까지 무사히 걷는 것"
        }
    }

    public var portraitNote: String {
        switch self {
        case .tori: return "볼주머니에 이슬방울 베리를 두 알 넣고 다닌다."
        case .songi: return "등의 가시에 잎사귀가 한 장 걸려 있다."
        case .mong: return "목에 두른 목도리는 스스로 짠 것."
        case .rubi: return "꼬리 끝이 늘 살짝 젖어 있다."
        case .luna: return "뿔 한쪽에 눈이 쌓여 있다. 털어도 다음 날이면 다시 쌓인다."
        case .coco: return "털 끝이 늘 젖어 있고, 손에는 조약돌을 하나 쥐고 있다."
        case .dallae: return "목깃에 달나방 가루가 묻어 있어 밤마다 아주 조금씩 빛난다."
        case .moru: return "우편 자루 끈이 어깨에 두 번 감겨 있다. 자루는 늘 반쯤 비어 있다."
        }
    }

    /// 호감도가 '가족'까지 오르면 일기장에 남는 마지막 한 줄.
    public var familyMemory: String {
        switch self {
        case .tori:
            return "이제 토리는 베리를 셀 때 나를 포함해서 센다. 하나, 둘, 셋, 그리고 옆자리."
        case .songi:
            return "송이가 정원 화분 이름표 끝에 내 이름을 같이 적었다. 지우개로 지우지 않았다."
        case .mong:
            return "몽이 낮에 잠들어 있는 모습을 처음 봤다. 밤에만 눈을 뜨는 새가 낮을 맡겨 준 셈이다."
        case .rubi:
            return "루비가 새 노래를 만들었다. 제목은 아직 없고, 가사 첫 줄은 내가 웃는 소리다."
        case .luna:
            return "루나의 별을 세는 종이에 이제 내 칸도 한 줄 있다. 겨울 칸 창가에 나란히 놓인 병 두 개."
        case .coco:
            return "코코가 조약돌 일곱 개를 내 손에 쥐여 주고, 여덟 번째는 같이 찾자고 했다."
        case .dallae:
            return "달래의 노래를 마지막 소절까지 들었다. 노래가 끝난 뒤, 달래는 처음으로 아무 말도 하지 않고 옆에 앉아 있었다."
        case .moru:
            return "모루가 다리 끝에서 자루를 내려놓았다. 무겁던 자루가 비어 있었고, 그제야 자기가 뭘 하고 다녔는지 말해 주었다."
        }
    }

    /// 프롤로그~에필로그의 숲을 이루는 네 이웃.
    public static var coreNeighbours: [CharacterID] {
        [.tori, .songi, .mong, .rubi]
    }

    /// 사계절 온실 확장팩에서 만나는 온실지기.
    public static var expansionNeighbours: [CharacterID] {
        [.luna, .coco]
    }

    /// 이야기를 마친 뒤 심야 구역에 찾아오는 방문 손님.
    public static var visitorNeighbours: [CharacterID] {
        [.dallae, .moru]
    }

    /// 확장팩 없이도 만날 수 있는 이웃인지.
    public var isExpansionCharacter: Bool {
        CharacterID.expansionNeighbours.contains(self)
    }

    /// 심야 구역의 방문 손님인지. 이야기를 마치기 전에는 얼굴을 보이지 않는다.
    public var isVisitorCharacter: Bool {
        CharacterID.visitorNeighbours.contains(self)
    }

    /// 이웃을 부르는 말. 화면의 작은 이름표에 쓴다.
    public var roleLabel: String {
        if isExpansionCharacter { return "온실지기" }
        if isVisitorCharacter { return "심야 손님" }
        return "숲의 이웃"
    }
}

/// 이웃의 호감도 단계.
/// 문턱을 높게 잡은 이유: 한두 번의 잼으로는 가까워지지 않고,
/// 여러 날에 걸쳐 잼을 나눠 먹거나 대화를 쌓아야 단짝이 된다.
public enum AffinityLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case shy = 0
    case greeting = 20
    case close = 150
    case family = 210

    public var title: String {
        switch self {
        case .shy: return "낯가림"
        case .greeting: return "인사하는 사이"
        case .close: return "단짝"
        case .family: return "가족"
        }
    }

    public var note: String {
        switch self {
        case .shy: return "아직 눈을 잘 못 마주친다."
        case .greeting: return "마주치면 고개를 끄덕여 준다."
        case .close: return "문 앞에 뭘 두고 갔는지 서로 안다."
        case .family: return "말하지 않아도 같은 창밖을 본다."
        }
    }

    public var heartCount: Int {
        switch self {
        case .shy: return 0
        case .greeting: return 1
        case .close: return 2
        case .family: return 3
        }
    }

    public static func < (lhs: AffinityLevel, rhs: AffinityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum AffinitySystem {
    public static let maximum = 240

    /// 같은 날 한 이웃에게 잼을 여러 번 건내면 반가움이 조금씩 잦아든다.
    /// 첫 잼은 온전히, 그 뒤로는 이 비율만큼만 호감도가 오른다.
    public static let dailyGiftFactors: [Double] = [1.0, 0.5, 0.3, 0.15]

    /// 그날 몇 번째 잼인지(0부터)에 따른 호감도 비율.
    public static func dailyGiftFactor(forGiftIndex index: Int) -> Double {
        guard index > 0 else { return 1 }
        if index < dailyGiftFactors.count { return dailyGiftFactors[index] }
        return dailyGiftFactors[dailyGiftFactors.count - 1]
    }

    public static func level(for points: Int) -> AffinityLevel {
        let clamped = max(0, min(maximum, points))
        var result: AffinityLevel = .shy
        for level in AffinityLevel.allCases where clamped >= level.rawValue {
            result = level
        }
        return result
    }

    /// 선물 점수. 최애 요리 > 좋아하는 요리 > 무난한 요리 > 싫어하는 요리 순.
    public static let favoritePoints = 12
    public static let likedPoints = 7
    public static let neutralPoints = 3
    public static let dislikedPoints = 1

    public static func baseGiftPoints(recipe: Recipe, for character: CharacterID) -> Int {
        if recipe.id == character.favoriteRecipeID { return favoritePoints }
        if character.likedRecipeIDs.contains(recipe.id) { return likedPoints }
        if character.dislikedRecipeIDs.contains(recipe.id) { return dislikedPoints }
        return neutralPoints
    }

    /// 대화 선택지로 오르는 호감도도 같은 상한을 쓴다.
    public static func clamped(_ points: Int) -> Int {
        max(0, min(maximum, points))
    }
}
