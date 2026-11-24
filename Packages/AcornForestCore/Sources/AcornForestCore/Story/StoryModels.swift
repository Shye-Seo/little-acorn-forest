import Foundation

/// 대사 한 줄의 화자.
public enum StorySpeaker: String, Codable, Sendable {
    case narrator
    case bori
    case tori
    case songi
    case mong
    case rubi
    case luna
    case coco

    public var displayName: String {
        switch self {
        case .narrator: return ""
        case .bori: return "보리"
        case .tori: return "토리"
        case .songi: return "송이"
        case .mong: return "몽"
        case .rubi: return "루비"
        case .luna: return "루나"
        case .coco: return "코코"
        }
    }

    public var character: CharacterID? {
        switch self {
        case .narrator, .bori: return nil
        case .tori: return .tori
        case .songi: return .songi
        case .mong: return .mong
        case .rubi: return .rubi
        case .luna: return .luna
        case .coco: return .coco
        }
    }

    public var isNarration: Bool { self == .narrator }
}

public struct StoryLine: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let speaker: StorySpeaker
    public let text: String

    public init(id: String, speaker: StorySpeaker, text: String) {
        self.id = id
        self.speaker = speaker
        self.text = text
    }
}

public struct AffinityGain: Codable, Hashable, Sendable {
    public var character: CharacterID
    public var amount: Int

    public init(_ character: CharacterID, _ amount: Int) {
        self.character = character
        self.amount = amount
    }
}

/// 선택지. 고르면 호감도가 오르고, 다음 장면에서 달라지는 대사가 하나 붙는다.
public struct StoryChoice: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let text: String
    public let gains: [AffinityGain]
    public let flag: String?
    public let reply: StoryLine?

    public init(id: String,
                text: String,
                gains: [AffinityGain] = [],
                flag: String? = nil,
                reply: StoryLine? = nil) {
        self.id = id
        self.text = text
        self.gains = gains
        self.flag = flag
        self.reply = reply
    }
}

public struct StoryScene: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let chapter: StoryChapter
    public let title: String
    public let lines: [StoryLine]
    public let choices: [StoryChoice]
    public let grants: [ItemStack]
    public let unlocksDiary: [String]
    public let closingThought: String

    public init(id: String,
                chapter: StoryChapter,
                title: String,
                lines: [StoryLine],
                choices: [StoryChoice] = [],
                grants: [ItemStack] = [],
                unlocksDiary: [String] = [],
                closingThought: String) {
        self.id = id
        self.chapter = chapter
        self.title = title
        self.lines = lines
        self.choices = choices
        self.grants = grants
        self.unlocksDiary = unlocksDiary
        self.closingThought = closingThought
    }

    public var lastLineIsChoicePoint: Bool { !choices.isEmpty }
}

/// 화면에 한 번에 보여 주는 대사 묶음.
public struct StoryBeat: Sendable, Equatable {
    public let sceneID: String
    public let sceneTitle: String
    public let chapter: StoryChapter
    public let line: StoryLine
    public let lineIndex: Int
    public let lineCount: Int
    public let isLastLine: Bool

    public init(sceneID: String,
                sceneTitle: String,
                chapter: StoryChapter,
                line: StoryLine,
                lineIndex: Int,
                lineCount: Int,
                isLastLine: Bool) {
        self.sceneID = sceneID
        self.sceneTitle = sceneTitle
        self.chapter = chapter
        self.line = line
        self.lineIndex = lineIndex
        self.lineCount = lineCount
        self.isLastLine = isLastLine
    }

    public var progressLabel: String { "\(lineIndex + 1) / \(lineCount)" }
}

/// 이야기 화면이 받는 한 걸음.
public enum StoryStep: Sendable, Equatable {
    /// 다음 대사가 있다.
    case line(StoryBeat)
    /// 마지막 대사 + 선택지. 고르면 이야기가 이어진다.
    case choice(StoryBeat, [StoryChoice])
    /// 장면 하나가 끝났다(다음 장면으로 넘어갈 준비).
    case sceneFinished(SceneSummary)
    /// 챕터가 통째로 끝났다.
    case completed(ChapterCompletion)
    /// 아직 열리지 않은 챕터.
    case blocked(String)

    public var beat: StoryBeat? {
        switch self {
        case .line(let beat): return beat
        case .choice(let beat, _): return beat
        case .sceneFinished, .completed, .blocked: return nil
        }
    }

    public var choices: [StoryChoice] {
        switch self {
        case .choice(_, let choices): return choices
        default: return []
        }
    }
}

public struct SceneSummary: Sendable, Equatable {
    public let chapter: StoryChapter
    public let sceneTitle: String
    public let thought: String
    public let gained: [ItemStack]
    public let unlockedDiary: [String]

    public init(chapter: StoryChapter,
                sceneTitle: String,
                thought: String,
                gained: [ItemStack],
                unlockedDiary: [String]) {
        self.chapter = chapter
        self.sceneTitle = sceneTitle
        self.thought = thought
        self.gained = gained
        self.unlockedDiary = unlockedDiary
    }
}

public struct ChapterCompletion: Sendable, Equatable {
    public let chapter: StoryChapter
    public let nextChapter: StoryChapter?
    public let unlockedDiary: String?
    public let message: String

    public init(chapter: StoryChapter,
                nextChapter: StoryChapter?,
                unlockedDiary: String?,
                message: String) {
        self.chapter = chapter
        self.nextChapter = nextChapter
        self.unlockedDiary = unlockedDiary
        self.message = message
    }
}
