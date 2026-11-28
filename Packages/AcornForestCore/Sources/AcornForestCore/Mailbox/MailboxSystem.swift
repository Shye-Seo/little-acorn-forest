import Foundation

/// 날짜가 바뀌었을 때 이웃이 우체통에 무엇을 두고 가는지 정하는 규칙.
/// 같은 날·같은 이웃이면 언제 계산해도 같은 편지가 나온다(시드 고정 난수).
public enum MailboxSystem {
    /// 편지를 남기는 이웃의 최소 호감도: 인사하는 사이(20).
    public static let affinityThreshold = AffinityLevel.greeting.rawValue
    /// 한 번에 확인했을 때 새로 들어오는 편지의 최대 수.
    public static let dailyLimit = 3
    /// 우체통에 쌓아 둘 수 있는 편지 수.
    public static let capacity = 10
    /// 이웃 한 명이 편지를 남길 확률.
    public static let letterChance = 0.62
    /// 편지가 쪽지(비밀 레시피)일 확률.
    public static let noteChance = 0.32

    /// 오늘 편지를 남길 수 있는 이웃. 확장 이웃은 온실을 가진 뒤에만,
    /// 심야 손님은 이야기를 마친 뒤에만 온다.
    public static func eligibleSenders(in state: GameState) -> [CharacterID] {
        CharacterID.allCases.filter { character in
            guard state.affinityPoints(for: character) >= affinityThreshold else { return false }
            if character.isExpansionCharacter && !state.owns(.greenhouse) { return false }
            if character.isVisitorCharacter && !state.isStoryComplete { return false }
            return true
        }
    }

    /// 지정한 날에 도착하는 편지들. 같은 날에는 몇 번을 계산해도 같은 결과다.
    public static func letters(forDay day: Int, state: GameState, now: Date = Date()) -> [MailboxLetter] {
        let senders = eligibleSenders(in: state)
        guard !senders.isEmpty else { return [] }

        var letters: [MailboxLetter] = []
        var availableNotes = SecretRecipeBook.unlearned(in: state.secretRecipes)
            .filter { recipe in
                !state.mailbox.contains { $0.secretRecipeID == recipe.id && !$0.isClaimed }
            }

        for (index, sender) in senders.enumerated() {
            var rng = SeededRandom(seed: daySeed(day: day, index: index))
            let roll = Double.random(in: 0..<1, using: &rng)
            guard roll < letterChance else { continue }

            let noteRoll = Double.random(in: 0..<1, using: &rng)
            var secretID: String?
            if noteRoll < noteChance, let recipe = availableNotes.first {
                secretID = recipe.id
                availableNotes.removeAll { $0.id == recipe.id }
            }

            var gift: ItemStack?
            if secretID == nil {
                gift = makeGift(for: sender, using: &rng)
            }

            letters.append(MailboxLetter(
                sender: sender,
                day: day,
                deliveredAt: now,
                gift: gift,
                secretRecipeID: secretID,
                note: letterText(sender: sender, secretID: secretID, gift: gift)
            ))

            if letters.count >= dailyLimit { break }
        }

        return letters
    }

    /// 날짜와 이웃 순번으로 만든 고정 시드.
    public static func daySeed(day: Int, index: Int) -> UInt64 {
        UInt64(truncatingIfNeeded: day) &* 1_000_003 &+ UInt64(index + 1) &* 9_176
    }

    /// 그 이웃이 좋아하는 잼의 재료를 우선으로 골라 준다.
    public static func giftPool(for character: CharacterID) -> [Ingredient] {
        var pool: [Ingredient] = []
        if let favorite = RecipeBook.recipe(id: character.favoriteRecipeID) {
            pool.append(contentsOf: favorite.ingredients)
        }
        if character.likedRecipeIDs.isEmpty == false,
           let liked = RecipeBook.recipe(id: character.likedRecipeIDs[0]) {
            pool.append(contentsOf: liked.ingredients)
        }
        pool.append(contentsOf: [.dewberry, .fireflyNectar, .starMossShroom])
        return pool.isEmpty ? Ingredient.basic : pool
    }

    static func makeGift(for character: CharacterID, using rng: inout SeededRandom) -> ItemStack {
        let pool = giftPool(for: character)
        let ingredient = pool[Int.random(in: 0..<pool.count, using: &rng)]
        let count = Int.random(in: 1...2, using: &rng)
        return ItemStack(ingredient, count)
    }

    static func letterText(sender: CharacterID, secretID: String?, gift: ItemStack?) -> String {
        if let secretID {
            return SecretRecipeBook.note(for: secretID, sender: sender)
        }
        guard let gift else {
            return "\(sender.name)이(가) 현관에 짧은 안부만 남기고 갔어요. “오늘도 잼 냄새가 좋네.”"
        }
        return "\(sender.name)이(가) 현관 우체통에 \(gift.ingredient.title) \(gift.count)개를 두고 갔어요. “어제 주워서 두 개는 못 먹고 남겼어.”"
    }
}
