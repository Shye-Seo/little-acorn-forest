import Foundation

/// 프롤로그부터 에필로그까지, 이야기의 다섯 마당.
public enum StoryChapter: String, CaseIterable, Codable, Identifiable, Sendable {
    case prologue
    case chapterOne
    case chapterTwo
    case chapterThree
    case epilogue

    public var id: String { rawValue }

    /// 지도와 일기장에서 쓰는 순번(1부터).
    public var order: Int {
        switch self {
        case .prologue: return 0
        case .chapterOne: return 1
        case .chapterTwo: return 2
        case .chapterThree: return 3
        case .epilogue: return 4
        }
    }

    public var title: String {
        switch self {
        case .prologue: return "프롤로그 · 할머니의 오두막"
        case .chapterOne: return "첫 번째 이야기 · 이웃의 이름"
        case .chapterTwo: return "두 번째 이야기 · 숲의 솥단지"
        case .chapterThree: return "세 번째 이야기 · 축제를 준비하는 밤"
        case .epilogue: return "에필로그 · 별빛 아래에서"
        }
    }

    public var shortTitle: String {
        switch self {
        case .prologue: return "프롤로그"
        case .chapterOne: return "1장"
        case .chapterTwo: return "2장"
        case .chapterThree: return "3장"
        case .epilogue: return "에필로그"
        }
    }

    public var subtitle: String {
        switch self {
        case .prologue: return "빈 오두막, 남겨진 수첩 한 권"
        case .chapterOne: return "문을 두드리는 이웃들"
        case .chapterTwo: return "재료를 모아 불을 피우는 법"
        case .chapterThree: return "네 사람의 소원을 한 식탁에"
        case .epilogue: return "축제는 결국 함께 먹는 저녁"
        }
    }

    public var previous: StoryChapter? {
        switch self {
        case .prologue: return nil
        case .chapterOne: return .prologue
        case .chapterTwo: return .chapterOne
        case .chapterThree: return .chapterTwo
        case .epilogue: return .chapterThree
        }
    }

    public var next: StoryChapter? {
        switch self {
        case .prologue: return .chapterOne
        case .chapterOne: return .chapterTwo
        case .chapterTwo: return .chapterThree
        case .chapterThree: return .epilogue
        case .epilogue: return nil
        }
    }

    public static var ordered: [StoryChapter] { allCases.sorted { $0.order < $1.order } }
}

/// 챕터의 진행 상태.
public enum ChapterStatus: String, Codable, CaseIterable, Sendable {
    case locked
    case available
    case inProgress
    case completed

    public var isPlayable: Bool {
        self == .available || self == .inProgress
    }
}

public struct ChapterProgress: Codable, Hashable, Sendable, Identifiable {
    public var chapter: StoryChapter
    public var status: ChapterStatus

    public var id: String { chapter.rawValue }

    public init(chapter: StoryChapter, status: ChapterStatus) {
        self.chapter = chapter
        self.status = status
    }
}

/// 이야기 도중 위치. 저장 파일에 그대로 들어간다.
public struct StoryPosition: Codable, Hashable, Sendable {
    public var chapter: StoryChapter
    public var sceneIndex: Int
    public var lineIndex: Int
    public var awaitingChoice: Bool

    public init(chapter: StoryChapter, sceneIndex: Int = 0, lineIndex: Int = 0, awaitingChoice: Bool = false) {
        self.chapter = chapter
        self.sceneIndex = sceneIndex
        self.lineIndex = lineIndex
        self.awaitingChoice = awaitingChoice
    }
}
