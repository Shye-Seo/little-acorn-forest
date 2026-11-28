import Foundation

/// 이야기를 마친 뒤 심야 구역(달나방 등불다리·별소금 샘)에서 만나는 방문 손님들의 이야기.
///
/// 챕터 대본(`StoryScene`)과 달리 진행도에 끼어들지 않는 곁가지 대화 묶음이다.
/// `DialogueScene`(온실 대화와 같은 형식)을 그대로 쓴다.
public enum MidnightGuests {
    /// 방문 손님과 대화를 처음 끝까지 읽으면 오르는 호감도.
    public static let affinityGain = 6
    /// 다리 위에서 처음 손님을 맞는 장면의 id.
    public static let welcomeID = "midnight.welcome"

    public static let all: [DialogueScene] = [
        welcome,
        dallaeFirst,
        dallaeClose,
        moruFirst,
        moruClose
    ]

    public static let welcome = DialogueScene(
        id: welcomeID,
        title: "심야 구역 · 달나방 등불다리",
        lines: [
            StoryLine(id: "mw-1", speaker: .narrator, text: "축제가 끝나고 한 달쯤 지난 밤. 오두막 뒤편, 그때까지 담장이던 자리에 작은 나무다리가 놓여 있었다. 난간마다 달나방이 앉아 등불처럼 빛났다."),
            StoryLine(id: "mw-2", speaker: .bori, text: "이 다리는… 어제까지만 해도 없었는데."),
            StoryLine(id: "mw-3", speaker: .narrator, text: "다리 끝에서 종소리 같은 것이 한 번 울렸다. 종이 아니라, 종 모양 꽃이 바람에 흔들린 소리였다."),
            StoryLine(id: "mw-4", speaker: .dallae, text: "밤이 길어지면 다리가 놓여. 누가 와서 건너가야 하거든. 너, 잼 삶는 집이지? 냄새가 여기까지 왔어."),
            StoryLine(id: "mw-5", speaker: .bori, text: "그런데 넌… 낮에는 어디 있어?"),
            StoryLine(id: "mw-6", speaker: .dallae, text: "낮에는 아무도 안 물어봐. 밤에만 와서 물어봐 주면 돼. 나는 그거면 충분해.")
        ],
        closingThought: "달나방들이 다리 난간을 따라 한 마리씩 앉았다. 다리를 건너면 별소금 샘이 나온다고, 달래가 아주 작게 덧붙였다."
    )

    public static let dallaeFirst = DialogueScene(
        id: "midnight.dallae.first",
        title: "노래를 멈추지 않는 새",
        lines: [
            StoryLine(id: "mg-d1", speaker: .dallae, text: "내 노래 들어 봤어? 마지막 소절이 제일 좋아. 대부분 거기까지 안 듣고 가는데."),
            StoryLine(id: "dallae-2", speaker: .bori, text: "여기 앉아서 끝까지 들을게."),
            StoryLine(id: "dallae-3", speaker: .narrator, text: "달래가 잠깐 멈칫했다. 그리고 아주 낮은 소리로, 처음부터 다시 불렀다."),
            StoryLine(id: "dallae-4", speaker: .dallae, text: "…이상하다. 듣는 사람이 있으면 끝이 조금 짧게 느껴져. 좋은 쪽으로.")
        ],
        closingThought: "노래가 끝나자 다리 위 달나방들이 한꺼번에 날개를 폈다. 달래는 그걸 세고 있었다."
    )

    public static let dallaeClose = DialogueScene(
        id: "midnight.dallae.close",
        title: "새벽 세 시의 마멀레이드",
        lines: [
            StoryLine(id: "mg-d2", speaker: .dallae, text: "심야 별빛 마멀레이드는 새벽 세 시에만 꺼내 먹어. 그때가 제일 별이 많아서."),
            StoryLine(id: "dallae-6", speaker: .bori, text: "그럼 오늘 새벽 세 시에 같이 먹자."),
            StoryLine(id: "dallae-7", speaker: .dallae, text: "…그럼 나, 오늘은 노래를 하나 덜 부를게. 대신 그 시간에 깨어 있을게.")
        ],
        closingThought: "새벽 세 시, 다리 위에 항아리 하나와 잔 두 개가 놓였다. 별이 두 번 지나갔다."
    )

    public static let moruFirst = DialogueScene(
        id: "midnight.moru.first",
        title: "자루를 멘 두더지",
        lines: [
            StoryLine(id: "mg-m1", speaker: .moru, text: "죄송합니다, 길을 좀 비켜 주시겠어요. 오늘 밤손님이 셋이라서요."),
            StoryLine(id: "moru-2", speaker: .bori, text: "밤손님을 데려다주는 거야?"),
            StoryLine(id: "moru-3", speaker: .moru, text: "다리 끝까지요. 그분들은 다음 숲으로 가야 하거든요. 자루에는 별소금 잼을 넣어 둡니다. 길에서 배고플까 봐."),
            StoryLine(id: "moru-4", speaker: .narrator, text: "자루는 반쯤 비어 있는데도 무거워 보였다. 모루는 그걸 어깨에 두 번 감아 메고 걸었다.")
        ],
        closingThought: "모루가 다리 끝에서 손님을 기다리게 두고, 잠깐 돌아와 말했다. “돌아올 길이 있으면 자루가 가벼워집니다.”"
    )

    public static let moruClose = DialogueScene(
        id: "midnight.moru.close",
        title: "돌아올 자리",
        lines: [
            StoryLine(id: "mg-m2", speaker: .moru, text: "오늘은 자루를 여기 두고 갈까 합니다. 무거워서가 아니라… 돌아올 자리가 있으면 좋아서요."),
            StoryLine(id: "moru-6", speaker: .bori, text: "그럼 문 옆에 걸어 둘게. 아무도 안 가져가."),
            StoryLine(id: "moru-7", speaker: .moru, text: "…그 말을 이십 년 만에 들었습니다.")
        ],
        closingThought: "다음 날 아침, 문 옆에는 자루가 걸려 있었고 그 안에 별소금 결정이 한 줌 들어 있었다."
    )

    public static func scene(id: String) -> DialogueScene? {
        all.first { $0.id == id }
    }

    /// 손님별 첫 대화와, 단짝이 된 뒤의 대화.
    public static func firstScene(for character: CharacterID) -> DialogueScene? {
        switch character {
        case .dallae: return dallaeFirst
        case .moru: return moruFirst
        default: return nil
        }
    }

    public static func closeScene(for character: CharacterID) -> DialogueScene? {
        switch character {
        case .dallae: return dallaeClose
        case .moru: return moruClose
        default: return nil
        }
    }
}
