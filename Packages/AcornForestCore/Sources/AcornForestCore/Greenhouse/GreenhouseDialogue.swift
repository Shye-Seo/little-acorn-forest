import Foundation

/// 잼 화면 밖에서 읽는 짧은 대화 묶음. 챕터 대본(StoryScene)과 달리 진행도에 끼어들지 않는다.
public struct DialogueScene: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let lines: [StoryLine]
    public let closingThought: String

    public init(id: String, title: String, lines: [StoryLine], closingThought: String) {
        self.id = id
        self.title = title
        self.lines = lines
        self.closingThought = closingThought
    }

    public var lineCount: Int { lines.count }
}

/// 사계절 온실에서 만나는 두 이웃의 첫 대화와, 그 뒤에 남는 이야기.
public enum GreenhouseDialogue {
    /// 대화를 처음 끝까지 읽으면 오르는 호감도.
    public static let affinityGain = 6
    public static let greetingID = "greenhouse.greeting"

    public static let all: [DialogueScene] = [
        intro,
        lunaFirst,
        lunaClose,
        cocoFirst,
        cocoClose
    ]

    public static let intro = DialogueScene(
        id: greetingID,
        title: "유리 지붕 아래",
        lines: [
            StoryLine(id: "gh-1", speaker: .narrator, text: "에필로그가 끝난 다음 날 아침, 오두막 뒤편에서 유리 지붕 하나가 빛을 받고 있었다. 할머니가 살아생전에 덮어 둔 문이었다."),
            StoryLine(id: "gh-2", speaker: .bori, text: "이런 문이 있었어? 어제까지만 해도 담장이었는데."),
            StoryLine(id: "gh-3", speaker: .luna, text: "담장은 계절이 바뀔 때마다 한 번씩 문이 됩니다. 올해는 그 문이 당신에게 열린 거예요."),
            StoryLine(id: "gh-4", speaker: .coco, text: "안쪽에 연못도 있어! 미끄러지면 진짜 재밌는데, 지금은 조약돌부터 굴려 볼래."),
            StoryLine(id: "gh-5", speaker: .bori, text: "…여기, 사계절이 한 번에 있네. 봄이랑 겨울이 바로 옆에 붙어 있어.")
        ],
        closingThought: "유리 아래에는 봄·여름·가을·겨울이 네 칸으로 나란히 서 있었다. 계절을 옮겨 심는 사람들이 여기 살고 있었다."
    )

    public static let lunaFirst = DialogueScene(
        id: "greenhouse.luna.first",
        title: "별을 세는 사슴",
        lines: [
            StoryLine(id: "gh-l1", speaker: .luna, text: "밤에 유리 위로 별이 지나가면, 나는 그 수를 세어 종이에 적습니다. 오늘은 아직 세 개예요."),
            StoryLine(id: "gh-l2", speaker: .bori, text: "세는 이유가 있어?"),
            StoryLine(id: "gh-l3", speaker: .luna, text: "수를 세는 동안에는 아무것도 잃지 않으니까요. 겨울이 와도, 화분이 얼어도, 그 밤은 종이 안에 남아 있어요."),
            StoryLine(id: "gh-l4", speaker: .narrator, text: "루나는 겨울 칸의 국화 옆에 종이를 한 장 놓아 두었다. 위쪽에 오늘 날짜와, 짧은 선 세 개가 그어져 있었다.")
        ],
        closingThought: "루나의 소원은 거창하지 않았다. 겨울에도 얼지 않는 화분 하나. 어쩌면 그건 오늘 밤 별을 세는 일과 같은 크기였다."
    )

    public static let lunaClose = DialogueScene(
        id: "greenhouse.luna.close",
        title: "겨울 칸의 등불",
        lines: [
            StoryLine(id: "gh-l5", speaker: .luna, text: "겨울 눈꽃 잼을 여기 두고 가도 될까요. 창가에 두면 밤이 조금 덜 추워 보여서요."),
            StoryLine(id: "gh-l6", speaker: .bori, text: "그럼 그 병은 루나 거야."),
            StoryLine(id: "gh-l7", speaker: .luna, text: "…그렇게 말해 주는 사람은 처음입니다. 그럼 제가 봄 칸 벚나무에 이름을 하나 붙여도 될까요.")
        ],
        closingThought: "겨울 칸 창가에 병 하나가 놓였다. 밤마다 그 병을 지나치는 별이 하나씩 늘었다."
    )

    public static let cocoFirst = DialogueScene(
        id: "greenhouse.coco.first",
        title: "조약돌을 굴리는 수달",
        lines: [
            StoryLine(id: "gh-c1", speaker: .coco, text: "이 조약돌, 만져 봐. 겨울 칸에서 가져온 건데도 아직 따뜻해."),
            StoryLine(id: "gh-c2", speaker: .bori, text: "진짜네. 유리 안쪽은 원래 따뜻한가 봐."),
            StoryLine(id: "gh-c3", speaker: .coco, text: "아니, 봄이 아직 이 돌을 기억하고 있는 거야. 나는 그게 좋아서 매일 굴려."),
            StoryLine(id: "gh-c4", speaker: .narrator, text: "연못가에 조약돌이 일곱 개 놓여 있었다. 코코는 하나씩 순서를 정해 두고 굴리는 것 같았다.")
        ],
        closingThought: "코코의 소원은 봄이 오는 날을 누군가와 같이 세는 일이었다. 세는 일은 혼자서도 되지만, 같이 하면 봄이 두 번 오는 것 같다고 했다."
    )

    public static let cocoClose = DialogueScene(
        id: "greenhouse.coco.close",
        title: "봄을 같이 세는 일",
        lines: [
            StoryLine(id: "gh-c5", speaker: .coco, text: "내일 아침, 같이 봄 칸부터 볼래? 벚꽃이 한 송이 더 필 거야."),
            StoryLine(id: "gh-c6", speaker: .bori, text: "좋아. 대신 조약돌은 네가 들고."),
            StoryLine(id: "gh-c7", speaker: .coco, text: "당연하지! 이건 내 거니까.")
        ],
        closingThought: "봄 칸 벚나무 아래에 조약돌 하나가 놓였다. 다음 아침, 꽃은 한 송이 더 피어 있었다."
    )

    public static func scene(id: String) -> DialogueScene? {
        all.first { $0.id == id }
    }

    /// 이웃별 첫 대화와, 단짝이 된 뒤의 대화.
    public static func firstScene(for character: CharacterID) -> DialogueScene? {
        switch character {
        case .luna: return lunaFirst
        case .coco: return cocoFirst
        default: return nil
        }
    }

    public static func closeScene(for character: CharacterID) -> DialogueScene? {
        switch character {
        case .luna: return lunaClose
        case .coco: return cocoClose
        default: return nil
        }
    }
}

/// 대화를 읽고 나서 엔진이 돌려주는 결과.
public struct DialogueOutcome: Sendable, Equatable {
    public let scene: DialogueScene
    public let gain: Int
    public let isFirstTime: Bool
    public let message: String

    public init(scene: DialogueScene, gain: Int, isFirstTime: Bool, message: String) {
        self.scene = scene
        self.gain = gain
        self.isFirstTime = isFirstTime
        self.message = message
    }
}
