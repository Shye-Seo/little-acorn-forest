import Foundation

/// 꾸며서 다락 선반에 진열한 잼 한 병.
public struct CustomJamJar: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var recipeID: String
    public var bottle: JarBottleStyle
    public var cap: JarCapStyle
    public var ribbon: JarRibbonColor
    /// 손글씨 라벨. 비어 있으면 레시피 이름으로 채운다.
    public var label: String
    public var madeAt: Date
    /// 만들어진 밤의 달 위상.
    public var moonPhase: MoonPhase
    /// 선반 칸 번호(0부터).
    public var slot: Int

    public init(id: String = UUID().uuidString,
                recipeID: String,
                bottle: JarBottleStyle = JarStyleCatalog.defaultBottle,
                cap: JarCapStyle = JarStyleCatalog.defaultCap,
                ribbon: JarRibbonColor = JarStyleCatalog.defaultRibbon,
                label: String = "",
                madeAt: Date = Date(),
                moonPhase: MoonPhase = .crescent,
                slot: Int = 0) {
        self.id = id
        self.recipeID = recipeID
        self.bottle = bottle
        self.cap = cap
        self.ribbon = ribbon
        self.label = label
        self.madeAt = madeAt
        self.moonPhase = moonPhase
        self.slot = slot
    }

    public var recipeName: String {
        RecipeBook.recipe(id: recipeID)?.name ?? recipeID
    }

    /// 병에 붙어 보이는 이름. 라벨을 비워 두면 레시피 이름을 쓴다.
    public var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? recipeName : trimmed
    }

    public var emojiLine: String {
        "\(bottle.emoji) \(RecipeBook.recipe(id: recipeID)?.ingredientEmojiLine ?? "🍯")"
    }

    public var detailLine: String {
        "\(bottle.title) · \(cap.title) · \(ribbon.title)"
    }

    public var moonLine: String {
        "\(moonPhase.emoji) \(moonPhase.title)에 담근 병"
    }
}

/// 다락 선반에 병을 놓고 빼는 규칙.
public enum JarShelf {
    /// 선반 한 단에 놓을 수 있는 병의 수(3 × 3).
    public static let capacity = 9
    public static let labelLimit = 18

    /// 라벨은 공백을 정리하고 길이를 자른다. 줄바꿈은 공백으로 바꾼다.
    public static func sanitizedLabel(_ text: String) -> String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let squeezed = flattened.split(separator: " ").joined(separator: " ")
        guard squeezed.count > labelLimit else { return String(squeezed) }
        return String(squeezed.prefix(labelLimit))
    }

    public static func defaultLabel(for recipeID: String) -> String {
        sanitizedLabel(RecipeBook.recipe(id: recipeID)?.name ?? "")
    }

    /// 선반에서 비어 있는 첫 칸. 자리가 없으면 nil.
    public static func firstFreeSlot(in jars: [CustomJamJar]) -> Int? {
        (0..<capacity).first { slot in
            !jars.contains { $0.slot == slot }
        }
    }

    public static func isFull(_ jars: [CustomJamJar]) -> Bool {
        firstFreeSlot(in: jars) == nil
    }

    /// 병을 뺀 뒤 빈 칸 없이 다시 앉힌다.
    public static func repacked(_ jars: [CustomJamJar]) -> [CustomJamJar] {
        jars.sorted { $0.slot < $1.slot }
            .prefix(capacity)
            .enumerated()
            .map { index, jar in
                var moved = jar
                moved.slot = index
                return moved
            }
    }

    /// 선반 정리: 칸 번호가 겹치거나 범위를 벗어난 병을 순서대로 다시 앉힌다.
    public static func normalized(_ jars: [CustomJamJar]) -> [CustomJamJar] {
        var used = Set<Int>()
        var result: [CustomJamJar] = []
        for var jar in jars {
            if jar.slot < 0 || jar.slot >= capacity || used.contains(jar.slot) {
                guard let slot = (0..<capacity).first(where: { !used.contains($0) }) else { continue }
                jar.slot = slot
            }
            used.insert(jar.slot)
            result.append(jar)
        }
        return result.sorted { $0.slot < $1.slot }
    }
}

/// 잼 병을 꾸밀 때 엔진이 돌려주는 결과.
public struct JarDecorationOutcome: Sendable, Equatable {
    public let succeeded: Bool
    public let jar: CustomJamJar?
    public let message: String

    public init(succeeded: Bool, jar: CustomJamJar?, message: String) {
        self.succeeded = succeeded
        self.jar = jar
        self.message = message
    }
}
