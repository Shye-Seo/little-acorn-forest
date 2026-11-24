import Foundation

/// 현관 우체통에 남겨진 편지 한 통.
public struct MailboxLetter: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var sender: CharacterID
    /// 편지가 놓인 날(UTC 일련번호).
    public var day: Int
    public var deliveredAt: Date
    /// 함께 두고 간 재료.
    public var gift: ItemStack?
    /// 수첩에 없는 비밀 레시피를 알려 주는 쪽지라면 그 레시피 id.
    public var secretRecipeID: String?
    public var note: String
    public var isClaimed: Bool

    public init(id: String = UUID().uuidString,
                sender: CharacterID,
                day: Int,
                deliveredAt: Date = Date(),
                gift: ItemStack? = nil,
                secretRecipeID: String? = nil,
                note: String,
                isClaimed: Bool = false) {
        self.id = id
        self.sender = sender
        self.day = day
        self.deliveredAt = deliveredAt
        self.gift = gift
        self.secretRecipeID = secretRecipeID
        self.note = note
        self.isClaimed = isClaimed
    }

    public var title: String {
        "\(sender.name)의 편지"
    }

    /// 우체통 목록에 보여 줄 한 줄.
    public var previewLine: String {
        if let gift {
            return "\(gift.ingredient.emoji) \(gift.ingredient.title) ×\(gift.count)를 두고 갔어요."
        }
        if secretRecipeID != nil {
            return "수첩에 없는 레시피 쪽지가 들어 있어요."
        }
        return "짧은 안부만 남기고 갔어요."
    }

    public var hasGift: Bool { (gift?.count ?? 0) > 0 }
    public var hasSecretRecipe: Bool { secretRecipeID != nil }
    public var isEmpty: Bool { !hasGift && !hasSecretRecipe }

    /// 수령 버튼 문구.
    public var claimTitle: String {
        isClaimed ? "받았어요" : "받기"
    }
}
