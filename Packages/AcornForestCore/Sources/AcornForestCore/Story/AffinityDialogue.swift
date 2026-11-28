import Foundation

/// 이웃의 호감도 구간마다 달라지는 한마디.
///
/// 같은 이웃이라도 '낯가림'과 '가족' 사이에는 말투가 다르다.
/// 이웃 화면과 선물 화면에서 지금 사이에 어울리는 대사 하나를 골라 보여 준다.
public enum AffinityDialogue {
    /// 호감도 단계별 대사. 네 단계 모두 채워 두면 화면이 그대로 쓴다.
    public static func line(for character: CharacterID, level: AffinityLevel) -> String {
        switch (character, level) {
        case (.tori, .shy):
            return "“…베리 세는 중이야. 잠깐만.” (고개는 들지 않는다.)"
        case (.tori, .greeting):
            return "“어, 왔어? 오늘 덤불 쪽이 좋아. 내가 먼저 가 있을게.”"
        case (.tori, .close):
            return "“네 몫으로 두 알 남겨 뒀어. 세어 보지도 마, 알겠지?”"
        case (.tori, .family):
            return "“오늘 저녁은 같이 먹는 거야. 안 그러면 내가 다 먹어.”"

        case (.songi, .shy):
            return "(잎사귀 뒤에서 눈만 빼꼼 내민다.)"
        case (.songi, .greeting):
            return "“…안녕. 오늘 물은, 조금만 줬어.”"
        case (.songi, .close):
            return "“이 화분, 이름 붙였어. 네가 말한 대로. …한 번만 더 불러 줘.”"
        case (.songi, .family):
            return "“문 앞에 화분 하나 더 놨어. 들어올 때 보이게.”"

        case (.mong, .shy):
            return "“밤에 오셨군요. 낮의 예절은 요구하지 않겠습니다.”"
        case (.mong, .greeting):
            return "“차를 끓여 두었습니다. 두 잔입니다. 한 잔은 제가 마시는 척할 겁니다.”"
        case (.mong, .close):
            return "“이 책갈피, 보시면 아실 겁니다. 접힌 자리가 당신이 앉던 쪽입니다.”"
        case (.mong, .family):
            return "“오늘은 제가 잠들어도 괜찮습니다. 불이 켜져 있으니까요.”"

        case (.rubi, .shy):
            return "“어! 새 얼굴! …아, 나 지금 바빠. 진짜로.” (꼬리가 흔들린다.)"
        case (.rubi, .greeting):
            return "“오늘 숲 소식 들을래? 세 개 있어. 아니, 다섯 개.”"
        case (.rubi, .close):
            return "“내 노래에 네 이름 넣어도 돼? 한 소절만. 조용한 데에.”"
        case (.rubi, .family):
            return "“노래 시작 전에 네가 웃는 소리부터 넣을 거야. 그게 제일 좋은 도입부야.”"

        case (.luna, .shy):
            return "“유리 아래는 밤에도 조금 따뜻합니다. 천천히 둘러보세요.”"
        case (.luna, .greeting):
            return "“오늘 밤에는 별이 두 개 지나갔습니다. 세어 두었어요.”"
        case (.luna, .close):
            return "“겨울 칸 창가에 병을 하나 두어도 될까요. 당신이 준 잼으로.”"
        case (.luna, .family):
            return "“세는 종이에 당신 칸을 만들었습니다. 거기는 얼지 않습니다.”"

        case (.coco, .shy):
            return "(연못가에서 조약돌을 굴리다 말고 고개를 갸웃한다.)"
        case (.coco, .greeting):
            return "“이 돌 만져 봐, 아직 따뜻해! 봄이 기억나는 거래.”"
        case (.coco, .close):
            return "“내일 아침 봄 칸부터 볼래? 꽃 한 송이 더 필 거야.”"
        case (.coco, .family):
            return "“조약돌 여덟 번째는 같이 찾자. 그건 네 거니까.”"

        case (.dallae, .shy):
            return "(다리 난간에 앉아 노래를 멈추지 않는다. 아직 이쪽을 보지 않는다.)"
        case (.dallae, .greeting):
            return "“밤이 길면 노래도 길어져. 한 소절만 들려줄까?”"
        case (.dallae, .close):
            return "“오늘은 마지막 소절을 아껴 뒀어. 네가 올 것 같아서.”"
        case (.dallae, .family):
            return "“노래가 끝나면 여기 앉아 있어. 아무 말 안 해도 돼.”"

        case (.moru, .shy):
            return "“자루가 무거워서요. …아니, 그냥 지나가는 길입니다.”"
        case (.moru, .greeting):
            return "“편지가 하나 더 늘었습니다. 어제보다 자루가 가볍네요.”"
        case (.moru, .close):
            return "“다리 끝까지 데려다주는 일, 오늘은 조금 천천히 걸어도 될까요.”"
        case (.moru, .family):
            return "“자루를 여기 두고 갈게요. 돌아올 자리가 생겼으니까.”"
        }
    }

    /// 아직 말을 걸기 전이거나 대사가 비어 있을 때의 안내.
    public static func fallback(for character: CharacterID) -> String {
        "\(character.name)이(가) 조용히 이쪽을 본다."
    }

    /// 지금 사이에 어울리는 대사. 호감도가 낮으면 낯가림 대사를 쓴다.
    public static func line(for character: CharacterID, points: Int) -> String {
        line(for: character, level: AffinitySystem.level(for: points))
    }

    /// 이웃이 처음 말을 걸 때의 한마디. 대사 데이터가 비어 있는지 확인하는 테스트에 쓴다.
    public static func allLines() -> [(CharacterID, AffinityLevel, String)] {
        CharacterID.allCases.flatMap { character in
            AffinityLevel.allCases.map { level in
                (character, level, line(for: character, level: level))
            }
        }
    }
}
