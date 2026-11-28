import Foundation

/// 이웃이 따로 부탁하는 '특별 의뢰'.
///
/// 하루 한 장 돌아오는 주문서(오늘의 주문서)와 달리, 한 번뿐이고 조건이 붙는다.
/// 정해진 잼을 한 접시 건네고 호감도 문턱을 넘으면 이웃이 자기 사정을 조금 더 말해 준다.
public struct SpecialRequest: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let character: CharacterID
    /// 건네야 하는 잼 id.
    public let recipeID: String
    /// 이 의뢰가 열리는 최소 호감도.
    public let minimumAffinity: AffinityLevel
    /// 이야기를 마친 뒤에만 열리는 의뢰인지.
    public let requiresStoryComplete: Bool
    /// 이 확장팩이 있어야 열리는 의뢰인지.
    public let requiredPack: ContentPack?
    /// 의뢰 카드에 보여 줄 부탁 한마디.
    public let note: String
    /// 건넸을 때 이웃이 남기는 말.
    public let thanks: String
    /// 의뢰를 마치면 받는 재료.
    public let reward: [ItemStack]
    /// 의뢰를 마치면 받는 반딧불이 가루.
    public let fireflyDust: Int

    public init(id: String,
                title: String,
                character: CharacterID,
                recipeID: String,
                minimumAffinity: AffinityLevel = .greeting,
                requiresStoryComplete: Bool = false,
                requiredPack: ContentPack? = nil,
                note: String,
                thanks: String,
                reward: [ItemStack],
                fireflyDust: Int = 0) {
        self.id = id
        self.title = title
        self.character = character
        self.recipeID = recipeID
        self.minimumAffinity = minimumAffinity
        self.requiresStoryComplete = requiresStoryComplete
        self.requiredPack = requiredPack
        self.note = note
        self.thanks = thanks
        self.reward = reward
        self.fireflyDust = fireflyDust
    }

    public var recipeName: String {
        RecipeBook.recipe(id: recipeID)?.name ?? recipeID
    }

    public var rewardLine: String {
        var parts = reward.map(\.label)
        if fireflyDust > 0 { parts.append("반딧불이 가루 ×\(fireflyDust)") }
        return parts.joined(separator: " · ")
    }
}

/// 특별 의뢰 다섯 장. 이야기를 마친 뒤의 심야 구역까지 고르게 쓰도록 배치했다.
public enum SpecialRequestBook {
    public static let dawnSongID = "request.dawn-song"
    public static let bridgeFarewellID = "request.bridge-farewell"
    public static let cometNightID = "request.comet-night"
    public static let winterWindowID = "request.winter-window"
    public static let gardenNameID = "request.garden-name"

    public static let all: [SpecialRequest] = [
        SpecialRequest(
            id: dawnSongID,
            title: "새벽 노래를 위한 잼",
            character: .dallae,
            recipeID: MidnightRecipes.bellCottonID,
            minimumAffinity: .greeting,
            requiresStoryComplete: true,
            note: "“새벽에 목이 잠겨서 노래가 자꾸 짧아져. 밤종꽃 솜잼이 있으면 마지막 소절까지 갈 수 있을 것 같아.”",
            thanks: "달래가 잼을 한 숟갈 뜨고, 그 자리에서 처음부터 다시 불렀다. 이번엔 끝까지 갔다. 노래가 끝난 뒤 달래가 말했다. “이거, 매일 새벽에 하나씩 먹어도 돼?”",
            reward: [ItemStack(.nightBellFlower, 2), ItemStack(.mothDustSugar, 1)],
            fireflyDust: 3
        ),
        SpecialRequest(
            id: bridgeFarewellID,
            title: "다리 위 밤손님 도시락",
            character: .moru,
            recipeID: MidnightRecipes.starSaltGlassID,
            minimumAffinity: .greeting,
            requiresStoryComplete: true,
            note: "“길 떠나는 손님들에게 뭘 쥐여 줄지 늘 고민입니다. 유리처럼 맑은 잼 하나면 오래 기억할 것 같습니다.”",
            thanks: "모루가 잼을 자루 맨 앞주머니에 조심히 넣었다. “이건 그분들 몫입니다. 대신 오는 길에 한 숟갈만 허락해 주세요.” 그리고 이십 년 만에 처음으로 웃었다.",
            reward: [ItemStack(.starSaltCrystal, 2), ItemStack(.dewberry, 2)],
            fireflyDust: 3
        ),
        SpecialRequest(
            id: cometNightID,
            title: "혜성 보는 밤",
            character: .mong,
            recipeID: MidnightRecipes.cometTrailID,
            minimumAffinity: .close,
            requiresStoryComplete: true,
            note: "“혜성이 지나가는 밤에는 서재 창이 잘 보이지 않습니다. 잼 위에 빛줄기가 남는 잼이 있다고 들었습니다. 그렇다면 오늘은 밤이 짧아도 괜찮습니다.”",
            thanks: "몽이 잼 항아리를 창가에 두고 촛불을 껐다. 잼 위의 빛줄기가 창틀에 닿아, 서재가 처음으로 별이 들어오는 방이 되었다.",
            reward: [ItemStack(.cometFeather, 1), ItemStack(.moonflakeSpice, 2)],
            fireflyDust: 4
        ),
        SpecialRequest(
            id: winterWindowID,
            title: "겨울 창가의 병",
            character: .luna,
            recipeID: GreenhouseRecipes.emberQuinceID,
            minimumAffinity: .greeting,
            requiredPack: .greenhouse,
            note: "“겨울 칸 창가에 두면 꽃이 얼지 않는 잼이 있다고 했습니다. 온기 모과 콩포트가 그 잼입니까. 병 하나만 이쪽으로 옮겨도 될까요.”",
            thanks: "루나가 병을 겨울 칸 창가에 놓고, 옆에 종이를 한 장 붙였다. 위쪽에 오늘 날짜와 짧은 선 세 개. 그 아래에 이번엔 네 번째 선이 그어져 있었다.",
            reward: [ItemStack(.emberQuince, 2), ItemStack(.snowBlossom, 1)],
            fireflyDust: 3
        ),
        SpecialRequest(
            id: gardenNameID,
            title: "정원 이름, 다섯 컵",
            character: .songi,
            recipeID: MidnightRecipes.bellMoonJellyID,
            minimumAffinity: .close,
            requiresStoryComplete: true,
            note: "“정원 이름표 옆에, 밤에만 우는 꽃을 심었어. 그 꽃으로 만든 젤리가 있으면 이름표를 다섯 개로 늘릴 수 있어.”",
            thanks: "송이가 젤리를 다섯 그릇에 나눠 담았다. 그리고 정원 이름표를 다섯 개로 늘려 달았다. “이제 이름이 하나 더 생겼어. 다섯 컵.”",
            reward: [ItemStack(.nightBellFlower, 2), ItemStack(.starMossShroom, 2)],
            fireflyDust: 4
        )
    ]

    public static var ids: [String] {
        all.map(\.id)
    }

    public static func request(id: String) -> SpecialRequest? {
        all.first { $0.id == id }
    }

    public static func requests(for character: CharacterID) -> [SpecialRequest] {
        all.filter { $0.character == character }
    }
}

/// 특별 의뢰를 마쳤을 때 돌아오는 결과.
public struct SpecialRequestOutcome: Sendable, Equatable {
    public let succeeded: Bool
    public let request: SpecialRequest?
    public let message: String
    public let affinityGain: Int
    public let gained: [ItemStack]

    public init(succeeded: Bool,
                request: SpecialRequest?,
                message: String,
                affinityGain: Int = 0,
                gained: [ItemStack] = []) {
        self.succeeded = succeeded
        self.request = request
        self.message = message
        self.affinityGain = affinityGain
        self.gained = gained
    }
}
