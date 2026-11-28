import Foundation

/// 이웃의 취향 단서. 말로만 쓰지 않고, 판정에 그대로 쓰이는 조건이기도 하다.
public struct OrderClue: Codable, Hashable, Sendable {
    /// 잼의 온기(1~3).
    public let warmth: Int?
    /// 반드시 들어가야 하는 재료.
    public let needsIngredient: Ingredient?
    /// 오늘은 빼 달라는 재료.
    public let avoidsIngredient: Ingredient?
    /// 달빛이 배어 있는 재료가 들어가야 하는지.
    public let wantsMoonlight: Bool

    public init(warmth: Int? = nil,
                needsIngredient: Ingredient? = nil,
                avoidsIngredient: Ingredient? = nil,
                wantsMoonlight: Bool = false) {
        self.warmth = warmth
        self.needsIngredient = needsIngredient
        self.avoidsIngredient = avoidsIngredient
        self.wantsMoonlight = wantsMoonlight
    }

    public var isEmpty: Bool {
        warmth == nil && needsIngredient == nil && avoidsIngredient == nil && !wantsMoonlight
    }
}

/// 오늘 이웃이 남긴 주문서 한 장.
public struct DailyOrder: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let day: Int
    public let character: CharacterID
    public let clue: OrderClue
    public let clueLine: String
    public let note: String
    public let basePoints: Int

    public init(id: String,
                day: Int,
                character: CharacterID,
                clue: OrderClue,
                clueLine: String,
                note: String,
                basePoints: Int) {
        self.id = id
        self.day = day
        self.character = character
        self.clue = clue
        self.clueLine = clueLine
        self.note = note
        self.basePoints = basePoints
    }
}

/// 주문을 하나 마쳤을 때 남는 기록. 하루에 한 장만 받는다.
public struct OrderRecord: Codable, Hashable, Sendable, Identifiable {
    public let day: Int
    public let character: CharacterID
    public let recipeID: String
    public let matched: Bool
    public let points: Int

    public init(day: Int, character: CharacterID, recipeID: String, matched: Bool, points: Int) {
        self.day = day
        self.character = character
        self.recipeID = recipeID
        self.matched = matched
        self.points = points
    }

    public var id: String { "\(day)-\(character.rawValue)" }
}

/// 주문서를 쌓아 올린 만큼 붙는 이름.
public enum OrderTitle: String, CaseIterable, Sendable, Identifiable {
    case apprentice
    case keeper
    case artisan
    case guardian

    public var id: String { rawValue }

    public var threshold: Int {
        switch self {
        case .apprentice: return 0
        case .keeper: return 30
        case .artisan: return 90
        case .guardian: return 180
        }
    }

    public var title: String {
        switch self {
        case .apprentice: return "솥단지 수습생"
        case .keeper: return "숲의 잼지기"
        case .artisan: return "달빛 주문 장인"
        case .guardian: return "항아리 지킴이"
        }
    }

    public var note: String {
        switch self {
        case .apprentice: return "이제 주문서를 읽기 시작했어요."
        case .keeper: return "이웃이 오늘 무엇을 먹고 싶은지, 조금씩 보여요."
        case .artisan: return "취향 단서 두 줄이면 답이 떠오릅니다."
        case .guardian: return "숲에서 잼 하면 이 집을 먼저 떠올립니다."
        }
    }

    public static func title(for points: Int) -> OrderTitle {
        allCases.last { points >= $0.threshold } ?? .apprentice
    }
}

/// 주문을 쌓으면 다락 선반에 놓이는 장식. 점수 문턱에서 열린다.
public enum OrderTrophy: String, Codable, CaseIterable, Sendable, Identifiable {
    case moonRibbon
    case silverWreath
    case fullMoonLantern

    public var id: String { rawValue }

    public var threshold: Int {
        switch self {
        case .moonRibbon: return 30
        case .silverWreath: return 90
        case .fullMoonLantern: return 180
        }
    }

    public var title: String {
        switch self {
        case .moonRibbon: return "달빛 리본 걸이"
        case .silverWreath: return "은빛 이파리 화환"
        case .fullMoonLantern: return "보름달 등불"
        }
    }

    public var emoji: String {
        switch self {
        case .moonRibbon: return "🎀"
        case .silverWreath: return "🌿"
        case .fullMoonLantern: return "🏮"
        }
    }

    public var note: String {
        switch self {
        case .moonRibbon: return "주문을 세 번쯤 맞히면 다락 기둥에 걸립니다. 라벨이 흔들릴 때 리본도 같이 흔들려요."
        case .silverWreath: return "이웃들이 하나씩 잎을 보태 준 화환. 겨울에도 마르지 않습니다."
        case .fullMoonLantern: return "주문을 꽤 많이 맞힌 집에만 달리는 등불. 밤에 다락이 조금 더 밝아집니다."
        }
    }
}

/// 주문을 마쳤을 때 돌아오는 결과.
public struct OrderOutcome: Sendable, Equatable {
    public let succeeded: Bool
    public let order: DailyOrder?
    public let recipeID: String
    public let matched: Bool
    public let points: Int
    public let streak: Int
    public let title: OrderTitle
    public let newTrophies: [OrderTrophy]
    public let energyGained: Bool
    public let message: String

    public init(succeeded: Bool,
                order: DailyOrder?,
                recipeID: String,
                matched: Bool,
                points: Int,
                streak: Int,
                title: OrderTitle,
                newTrophies: [OrderTrophy],
                energyGained: Bool,
                message: String) {
        self.succeeded = succeeded
        self.order = order
        self.recipeID = recipeID
        self.matched = matched
        self.points = points
        self.streak = streak
        self.title = title
        self.newTrophies = newTrophies
        self.energyGained = energyGained
        self.message = message
    }
}

/// 「이웃의 오늘의 비밀 주문서」.
///
/// 3장을 마치면 열린다. 하루에 한 장, 이웃 한 명이 취향 단서를 남기고,
/// 단서에 맞는 잼을 골라 건네면 누적 점수·칭호·선반 장식이 쌓인다.
/// 단서는 그날의 날짜와 이웃으로 시드를 만들어, 같은 날에는 늘 같은 주문이 나온다.
public enum DailyOrderBoard {
    /// 주문서가 열리는 이야기 지점.
    public static let unlockChapter: StoryChapter = .chapterThree
    /// 주문서가 열리려면 수첩에 담근 잼이 이만큼은 있어야 한다.
    public static let minimumRecipes = 2
    /// 하루에 받는 주문 수.
    public static let ordersPerDay = 1
    /// 맞혔을 때의 기본 점수.
    public static let basePoints = 10
    /// 빗나갔을 때도 남는 점수(그래도 잘 먹었으니까).
    public static let missPoints = 2
    /// 연속으로 맞힌 만큼 더 붙는 점수의 상한.
    public static let streakBonusCap = 5

    public static func isUnlocked(in state: GameState) -> Bool {
        guard state.status(of: unlockChapter) == .completed else { return false }
        return state.cookedRecipeCount >= minimumRecipes
    }

    /// 오늘의 주문. 아직 열리지 않았거나 단서를 만들 잼이 모자라면 nil.
    public static func order(forDay day: Int, in state: GameState) -> DailyOrder? {
        guard isUnlocked(in: state) else { return nil }
        let pool = RecipeBook.visibleRecipes(for: state)
        guard pool.count >= minimumRecipes else { return nil }
        guard let character = character(forDay: day, in: state) else { return nil }
        guard let target = targetRecipe(forDay: day, character: character, pool: pool) else { return nil }

        let clue = makeClue(target: target, pool: pool)
        return DailyOrder(
            id: "order.\(day).\(character.rawValue)",
            day: day,
            character: character,
            clue: clue,
            clueLine: clueLine(for: clue),
            note: note(for: character, clue: clue),
            basePoints: basePoints
        )
    }

    /// 단서에 맞는 잼인지. 주문서의 답은 하나로 고정하지 않고, 단서를 만족하는 잼이면 모두 인정한다.
    public static func matches(_ recipe: Recipe, clue: OrderClue) -> Bool {
        if let warmth = clue.warmth, recipe.warmth != warmth { return false }
        if let needs = clue.needsIngredient, !recipe.ingredients.contains(needs) { return false }
        if let avoids = clue.avoidsIngredient, recipe.ingredients.contains(avoids) { return false }
        if clue.wantsMoonlight, !recipe.ingredients.contains(where: \.carriesMoonlight) { return false }
        return true
    }

    /// 단서를 모두 만족하는 잼 목록(수첩 기준).
    public static func matchingRecipes(for order: DailyOrder, in state: GameState) -> [Recipe] {
        RecipeBook.visibleRecipes(for: state).filter { matches($0, clue: order.clue) }
    }

    /// 맞혔을 때 주는 점수. 온기가 깊은 잼일수록, 연속으로 맞힐수록 더 붙는다.
    public static func reward(for order: DailyOrder, streak: Int) -> Int {
        var points = order.basePoints + (order.clue.warmth ?? 1) * 2
        if order.clue.wantsMoonlight { points += 3 }
        points += min(max(0, streak), streakBonusCap)
        return points
    }

    public static func trophies(unlockedAt points: Int) -> [OrderTrophy] {
        OrderTrophy.allCases.filter { points >= $0.threshold }
    }

    /// 새로 열린 장식 목록.
    public static func newlyUnlockedTrophies(at points: Int, alreadyOwned: [String]) -> [OrderTrophy] {
        trophies(unlockedAt: points).filter { !alreadyOwned.contains($0.rawValue) }
    }

    // MARK: - 주문 만들기

    /// 오늘 주문을 남길 이웃. 인사하는 사이부터, 확장 이웃은 온실을 가진 뒤에만,
    /// 심야 손님은 이야기를 마친 뒤에만 들어온다.
    public static func eligibleCharacters(in state: GameState) -> [CharacterID] {
        CharacterID.allCases.filter { character in
            guard state.affinityPoints(for: character) >= AffinityLevel.greeting.rawValue else { return false }
            if character.isExpansionCharacter && !state.owns(.greenhouse) { return false }
            if character.isVisitorCharacter && !state.isStoryComplete { return false }
            return true
        }
    }

    public static func character(forDay day: Int, in state: GameState) -> CharacterID? {
        let eligible = eligibleCharacters(in: state)
        guard !eligible.isEmpty else { return nil }
        let index = Int(mix(day, salt: 1) % UInt64(eligible.count))
        return eligible[index]
    }

    /// 날짜와 소금으로 섞은 값. 같은 날이면 언제나 같은 주문이 나온다.
    static func mix(_ value: Int, salt: Int) -> UInt64 {
        var x = UInt64(truncatingIfNeeded: value) &* 0x9E37_79B9_7F4A_7C15
        x = x &+ UInt64(truncatingIfNeeded: salt) &* 0xD1B5_4A32_D192_ED03
        x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
        return x ^ (x >> 31)
    }

    static func targetRecipe(forDay day: Int, character: CharacterID, pool: [Recipe]) -> Recipe? {
        guard !pool.isEmpty else { return nil }
        let liked = Set(character.likedRecipeIDs)
        var candidates: [Recipe] = []
        if let favourite = pool.first(where: { $0.id == character.favoriteRecipeID }) {
            candidates.append(favourite)
        }
        candidates.append(contentsOf: pool.filter { liked.contains($0.id) && $0.id != character.favoriteRecipeID }
            .sorted { $0.id < $1.id })
        // 가끔은 최애가 아닌 잼을 찾는 날도 있다. 그래야 단서가 매번 같지 않다.
        let prefersFavourite = mix(day, salt: 3) % 100 < 60
        if candidates.isEmpty || !prefersFavourite {
            candidates = pool.sorted { $0.id < $1.id }
        }
        let index = Int(mix(day, salt: 2) % UInt64(candidates.count))
        return candidates[index]
    }

    /// 목표 잼에서 단서를 뽑는다. 처음엔 온기 하나로 시작하고,
    /// 답이 너무 많으면 재료 조건을 하나씩 더 붙여 좁힌다.
    static func makeClue(target: Recipe, pool: [Recipe]) -> OrderClue {
        let base = OrderClue(warmth: target.warmth)
        if count(base, in: pool) <= 2 || pool.count <= 2 { return base }

        // 목표에만 들어가는 재료를 고른다(다른 잼에 적게 쓰일수록 좋은 단서).
        let others = pool.filter { $0.id != target.id }
        let candidates = target.ingredients.sorted { lhs, rhs in
            let l = others.filter { $0.ingredients.contains(lhs) }.count
            let r = others.filter { $0.ingredients.contains(rhs) }.count
            return l == r ? lhs.rawValue < rhs.rawValue : l < r
        }
        var needs: Ingredient?
        if let pick = candidates.first {
            needs = pick
            let clue = OrderClue(warmth: target.warmth, needsIngredient: needs)
            if count(clue, in: pool) <= 2 { return clue }
        }

        // 빼야 할 재료: 목표에 없으면서 남은 후보에 가장 많이 쓰인 재료.
        var avoids: Ingredient?
        let narrowed = OrderClue(warmth: target.warmth, needsIngredient: needs)
        if count(narrowed, in: pool) > 2 {
            let avoidCandidates = Ingredient.allCases
                .filter { !target.ingredients.contains($0) }
                .filter { ingredient in others.contains { $0.ingredients.contains(ingredient) } }
                .sorted { lhs, rhs in
                    let l = others.filter { $0.ingredients.contains(lhs) }.count
                    let r = others.filter { $0.ingredients.contains(rhs) }.count
                    return l == r ? lhs.rawValue < rhs.rawValue : l > r
                }
            if let pick = avoidCandidates.first {
                avoids = pick
                let clue = OrderClue(warmth: target.warmth,
                                     needsIngredient: needs,
                                     avoidsIngredient: avoids)
                if count(clue, in: pool) <= 2 { return clue }
            }
        }

        // 마지막으로 달빛 조건. 목표에 달빛 재료가 있을 때만 붙일 수 있다.
        if target.ingredients.contains(where: \.carriesMoonlight) {
            return OrderClue(warmth: target.warmth,
                             needsIngredient: needs,
                             avoidsIngredient: avoids,
                             wantsMoonlight: true)
        }
        return OrderClue(warmth: target.warmth,
                         needsIngredient: needs,
                         avoidsIngredient: avoids)
    }

    static func count(_ clue: OrderClue, in pool: [Recipe]) -> Int {
        pool.filter { matches($0, clue: clue) }.count
    }

    // MARK: - 문구

    public static func warmthLine(_ warmth: Int) -> String {
        switch warmth {
        case 1: return "아주 가볍고 맑은"
        case 2: return "은근하고 뭉근한"
        default: return "손이 많이 간 깊은"
        }
    }

    public static func clueLine(for clue: OrderClue) -> String {
        var parts: [String] = []
        if let warmth = clue.warmth {
            parts.append("오늘은 \(warmthLine(warmth)) 잼이 먹고 싶어.")
        }
        if let needs = clue.needsIngredient {
            parts.append("\(needs.title) 향이 살짝 나야 해.")
        }
        if let avoids = clue.avoidsIngredient {
            parts.append("\(avoids.title)는 오늘은 넣지 말아 줘.")
        }
        if clue.wantsMoonlight {
            parts.append("달빛이 한 번 스친 맛이면 더 좋고.")
        }
        return parts.isEmpty ? "오늘은 아무거나 좋아. 네가 끓인 거면." : parts.joined(separator: " ")
    }

    public static func note(for character: CharacterID, clue: OrderClue) -> String {
        switch character {
        case .tori:
            return "“아침에 바구니 정리하다가 생각났어. 오늘은 단것 말고, 조금 깊은 맛이 났으면 좋겠어. 잼 값은 내가 베리로 칠게!”"
        case .songi:
            return "…“정원에 이름 붙인 뒤로, 저녁마다 잼 생각이 나. 조용한 맛이면 좋겠어. 향이 먼저 오는 걸로.”"
        case .mong:
            return "“밤에 먹을 잼입니다. 별이 창문으로 들어오는 밤이라, 그런 맛이면 좋겠습니다. 서두르지 않으셔도 됩니다.”"
        case .rubi:
            return "“오늘 소식통이 알려 줬어! 너한테 주문 넣으면 잼이 온대! 노래 부르기 전에 먹을 거니까 향이 확 퍼지는 걸로!”"
        case .luna:
            return "“유리 지붕 아래에서 계절을 세다 보면, 입안에도 계절이 하나 있었으면 해. 오늘은 그런 잼.”"
        case .coco:
            return "“연못가에 앉아서 먹을 거야. 조약돌 굴리다 손이 심심하면 잼 한 숟갈 떠서. 오늘은 그런 날.”"
        case .dallae:
            return "“오늘은 노래 중간에 배가 꼬였어. 달콤하지만 밤처럼 조용한 맛이면 좋겠어. 마지막 소절까지 부를 수 있게.”"
        case .moru:
            return "“길 떠나는 손님 몫으로 하나 부탁합니다. 오래 들고 가도 상하지 않으면서, 맑은 잼이면 좋겠습니다.”"
        }
    }

    /// 결과 카드에 쓰는 한 줄.
    public static func resultLine(order: DailyOrder, matched: Bool, points: Int) -> String {
        if matched {
            return "\(order.character.name)의 주문을 맞혔어요. 주문 점수 +\(points)"
        }
        return "\(order.character.name)은 웃으면서 다 먹었지만, 오늘 원한 맛은 아니었나 봐요. 주문 점수 +\(points)"
    }
}
