import Foundation
import AcornForestCore

/// 화면에 그대로 붙는 짧은 문구들. 테스트에서도 이 함수만 확인한다.
enum AppText {
    static func hearts(for level: AffinityLevel) -> String {
        let filled = String(repeating: "♥", count: level.heartCount)
        let empty = String(repeating: "♡", count: max(0, 3 - level.heartCount))
        return filled + empty
    }

    static func affinityLine(name: String, points: Int, level: AffinityLevel) -> String {
        "\(name) · \(level.title) \(points)/\(AffinitySystem.maximum)"
    }

    static func timer(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func percent(_ value: Double) -> String {
        let clamped = min(1, max(0, value))
        return "\(Int((clamped * 100).rounded()))%"
    }

    static func stockLine(_ stack: ItemStack) -> String {
        "\(stack.ingredient.emoji) \(stack.ingredient.title) \(stack.count)"
    }

    static func chapterLine(_ chapter: StoryChapter, status: ChapterStatus) -> String {
        "\(chapter.shortTitle) · \(statusLabel(status))"
    }

    static func statusLabel(_ status: ChapterStatus) -> String {
        switch status {
        case .locked: return "잠김"
        case .available: return "새 이야기"
        case .inProgress: return "진행 중"
        case .completed: return "완료"
        }
    }

    static func qualityLine(_ quality: CookingQuality) -> String {
        "\(quality.emoji) \(quality.title)"
    }

    static func summaryLine(_ summary: GatheringSummary) -> String {
        "\(summary.location.title) · \(summary.caughtCount)개 · \(percent(summary.accuracy)) 적중"
    }
}
