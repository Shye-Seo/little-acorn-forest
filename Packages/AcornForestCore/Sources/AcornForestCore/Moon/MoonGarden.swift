import Foundation

/// 보름달 밤에만 열리는 비밀 채집터의 규칙.
public enum MoonGarden {
    public static let location: ForestLocation = .moonlitGarden
    public static let rareIngredient: Ingredient = .moonlitDew
    /// 정원에 들어가려면 이야기가 어디까지 열려 있어야 하는가.
    public static let requiredChapter: StoryChapter = .chapterOne

    public static func isOpen(phase: MoonPhase) -> Bool {
        phase.opensSecretGarden
    }

    public static var openMessage: String {
        "달이 꽉 찼어요. 담장 사이로 달빛 비밀 정원의 길이 열렸습니다."
    }

    public static func closedMessage(daysUntilFullMoon: Double) -> String {
        let days = max(1, Int(daysUntilFullMoon.rounded(.up)))
        return "오늘은 \(formatPhase(.fullMoon))이 아니에요. 달빛 비밀 정원은 보름달 밤에만 열립니다. 다음 보름달까지 \(days)일."
    }

    /// 지도 안내 줄. 열려 있으면 지금 들어갈 수 있다고 알린다.
    public static func statusLine(phase: MoonPhase, daysUntilFullMoon: Double) -> String {
        if isOpen(phase: phase) {
            return "달빛 비밀 정원이 열렸어요 · 월광 이슬을 주울 수 있어요"
        }
        return closedMessage(daysUntilFullMoon: daysUntilFullMoon)
    }

    private static func formatPhase(_ phase: MoonPhase) -> String {
        "\(phase.emoji) \(phase.title)"
    }
}
