import Foundation

/// 숲에 사는 이웃들. 주인공 '보리'는 이 목록 밖의 화자로 다룬다.
public enum CharacterID: String, CaseIterable, Codable, Identifiable, Sendable {
    case tori
    case songi
    case mong
    case rubi

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .tori: return "토리"
        case .songi: return "송이"
        case .mong: return "몽"
        case .rubi: return "루비"
        }
    }

    public var species: String {
        switch self {
        case .tori: return "다람쥐"
        case .songi: return "고슴도치"
        case .mong: return "올빼미"
        case .rubi: return "여우"
        }
    }

    public var personality: String {
        switch self {
        case .tori:
            return "아침부터 저녁까지 부지런하다. 말이 많고 셈이 빠르지만, 남의 바구니가 비면 자기 도토리를 먼저 내민다."
        case .songi:
            return "낯을 많이 가려서 말을 걸면 잎 뒤에 숨는다. 대신 자기 정원의 버섯 이름은 전부 외우고 있다."
        case .mong:
            return "밤에만 눈을 뜨는 서재지기. 감정을 말로 잘 하지 않아서, 다정함은 늘 책갈피에 끼워 두고 산다."
        case .rubi:
            return "숲에서 제일 수다스럽다. 소문을 옮기는 걸 좋아하지만, 정작 어려운 이웃의 이야기는 함부로 꺼내지 않는다."
        }
    }

    public var favoriteRecipeID: String {
        switch self {
        case .tori: return "acorn-pie"
        case .songi: return "mushroom-soup"
        case .mong: return "moonlight-tea"
        case .rubi: return "raspberry-jam"
        }
    }

    public var likedRecipeIDs: [String] {
        switch self {
        case .tori: return ["forest-mushroom-pie", "grandma-porridge"]
        case .songi: return ["forest-mushroom-pie", "grandma-porridge"]
        case .mong: return ["grandma-porridge"]
        case .rubi: return ["starlight-cake"]
        }
    }

    public var dislikedRecipeIDs: [String] {
        switch self {
        case .tori: return ["moonlight-tea"]
        case .songi: return ["starlight-cake"]
        case .mong: return ["forest-mushroom-pie"]
        case .rubi: return ["grandma-porridge"]
        }
    }

    /// 이웃마다 숲의 별빛 축제에 걸고 있는 소원.
    public var wish: String {
        switch self {
        case .tori:
            return "잔뜩 모은 도토리를 누군가와 나눠 먹는 저녁"
        case .songi:
            return "정원에 이름을 붙여 주는 사람"
        case .mong:
            return "서재 창문으로 별이 한 번 더 들어오는 밤"
        case .rubi:
            return "숲 전체가 같이 웃는 노래"
        }
    }

    public var portraitNote: String {
        switch self {
        case .tori: return "볼주머니에 도토리를 두 개 넣고 다닌다."
        case .songi: return "등의 가시에 잎사귀가 한 장 걸려 있다."
        case .mong: return "목에 두른 목도리는 스스로 짠 것."
        case .rubi: return "꼬리 끝이 늘 살짝 젖어 있다."
        }
    }
}

/// 이웃의 호감도 단계.
public enum AffinityLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case shy = 0
    case greeting = 20
    case close = 45
    case family = 70

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
    public static let maximum = 100

    public static func level(for points: Int) -> AffinityLevel {
        let clamped = max(0, min(maximum, points))
        var result: AffinityLevel = .shy
        for level in AffinityLevel.allCases where clamped >= level.rawValue {
            result = level
        }
        return result
    }

    /// 선물 점수. 최애 요리 > 좋아하는 요리 > 무난한 요리 > 싫어하는 요리 순.
    public static func baseGiftPoints(recipe: Recipe, for character: CharacterID) -> Int {
        if recipe.id == character.favoriteRecipeID { return 12 }
        if character.likedRecipeIDs.contains(recipe.id) { return 7 }
        if character.dislikedRecipeIDs.contains(recipe.id) { return 1 }
        return 3
    }

    /// 대화 선택지로 오르는 호감도도 같은 상한을 쓴다.
    public static func clamped(_ points: Int) -> Int {
        max(0, min(maximum, points))
    }
}
