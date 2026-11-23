import Foundation

/// 프롤로그부터 에필로그까지의 대본.
/// 대사·선택지·보상이 모두 데이터라서, 엔진은 장면 순서만 관리하면 된다.
public enum StoryScript {
    public static let all: [StoryScene] = [
        prologueKey,
        prologueNotebook,
        chapterOneLibrary,
        chapterOneBush,
        chapterTwoGarden,
        chapterTwoKitchen,
        chapterThreeWishes,
        chapterThreeLanterns,
        epilogueNight
    ]

    public static func scenes(in chapter: StoryChapter) -> [StoryScene] {
        all.filter { $0.chapter == chapter }
    }

    public static func scene(id: String) -> StoryScene? {
        all.first { $0.id == id }
    }

    public static func scene(chapter: StoryChapter, index: Int) -> StoryScene? {
        let list = scenes(in: chapter)
        guard index >= 0, index < list.count else { return nil }
        return list[index]
    }

    public static var sceneCount: Int { all.count }

    // MARK: - 프롤로그

    private static let prologueKey = StoryScene(
        id: "prologue.key",
        chapter: .prologue,
        title: "화분 밑의 열쇠",
        lines: [
            StoryLine(id: "p1-1", speaker: .narrator, text: "기차를 두 번 갈아타고, 버스가 더는 가지 않는 곳에서 내렸다. 길은 거기서부터 흙이었다."),
            StoryLine(id: "p1-2", speaker: .narrator, text: "할머니가 떠난 뒤로 아무도 살지 않는 오두막. 문 앞에는 화분 하나가 남아 있었다. 겨울을 두 번 넘긴 잎이 아직 초록이다."),
            StoryLine(id: "p1-3", speaker: .bori, text: "열쇠는… 화분 밑에 두라고 하셨지."),
            StoryLine(id: "p1-4", speaker: .narrator, text: "흙을 털어 내자 손바닥에 작은 쇠가 떨어졌다. 오래된 열쇠인데 이상하게 따뜻했다."),
            StoryLine(id: "p1-5", speaker: .tori, text: "거기! 그거 할머니 열쇠 맞지? 세 번째 봄까지 기다린 보람이 있네."),
            StoryLine(id: "p1-6", speaker: .bori, text: "…다람쥐가 말을 해?"),
            StoryLine(id: "p1-7", speaker: .tori, text: "다람쥐가 말을 하면 안 된다는 법은 없잖아. 아무튼, 네가 새 주인이라면 나랑 잠깐 거래하자. 나는 숲을 잘 알고, 너는 집을 가지고 있으니까.")
        ],
        choices: [
            StoryChoice(
                id: "p1-c1",
                text: "일단 들어가서 따뜻한 것부터 먹자",
                gains: [AffinityGain(.tori, 4)],
                flag: "prologue.warmFirst",
                reply: StoryLine(id: "p1-c1-r", speaker: .tori, text: "밥…? 그거 좋은데. 대신 새벽이슬 잼이 좋아. 이슬이 마르기 전에 딴 베리로 만든 거.")
            ),
            StoryChoice(
                id: "p1-c2",
                text: "집 안부터 살펴볼래",
                gains: [AffinityGain(.tori, 2)],
                flag: "prologue.exploreFirst",
                reply: StoryLine(id: "p1-c2-r", speaker: .tori, text: "뭐, 그것도 맞지. 집주인이 집을 모르면 안 되니까. 나는 문 앞에서 기다릴게.")
            )
        ],
        grants: [],
        unlocksDiary: [],
        closingThought: "열쇠를 돌리자 문이 생각보다 가볍게 열렸다. 안에서는 아직 할머니의 비누 냄새가 났다."
    )

    private static let prologueNotebook = StoryScene(
        id: "prologue.notebook",
        chapter: .prologue,
        title: "할머니의 수첩",
        lines: [
            StoryLine(id: "p2-1", speaker: .narrator, text: "부엌 선반에는 낡은 수첩과, 누렇게 바랜 초대장이 나란히 놓여 있었다."),
            StoryLine(id: "p2-2", speaker: .bori, text: "‘숲의 별빛 축제 — 네 사람의 소원이 한자리에 모이면, 숲이 스스로 불을 밝힌다.’"),
            StoryLine(id: "p2-3", speaker: .tori, text: "할머니가 매년 하던 거야. 근데 마지막 축제는… 아무도 못 왔어."),
            StoryLine(id: "p2-4", speaker: .bori, text: "왜?"),
            StoryLine(id: "p2-5", speaker: .tori, text: "저마다 사정이 생겼지. 송이는 사람이 무서워서 숨고, 몽은 밤에만 눈을 뜨고, 루비는 말은 많은데 정작 자기 얘기는 안 해. 나도… 베리를 세다가 날짜를 잊었고."),
            StoryLine(id: "p2-6", speaker: .bori, text: "그럼 이번엔 내가 모아 볼게. 네 명이면 되는 거잖아."),
            StoryLine(id: "p2-7", speaker: .tori, text: "…너, 이상한 애다. 서울에서 온 애가 왜 이렇게 숲 말을 잘해. 좋아, 소개는 내가 해 줄게. 대신 잼은 네가 담글 것.")
        ],
        choices: [],
        grants: [ItemStack(.dewberry, 2)],
        unlocksDiary: [],
        closingThought: "오두막의 불을 켰다. 창밖에서 누군가 조용히 베리를 떨어뜨리는 소리가 났다."
    )

    // MARK: - 1장

    private static let chapterOneLibrary = StoryScene(
        id: "ch1.library",
        chapter: .chapterOne,
        title: "서재의 촛불",
        lines: [
            StoryLine(id: "c1a-1", speaker: .narrator, text: "숲 안쪽, 책이 무너질 듯 쌓인 서재에서 촛불 하나가 아직 꺼지지 않고 있었다."),
            StoryLine(id: "c1a-2", speaker: .mong, text: "문을 두드리지 않고 들어왔군요. 할머니는 늘 세 번 두드렸는데."),
            StoryLine(id: "c1a-3", speaker: .bori, text: "미안해요. 불이 켜져 있어서 그냥…"),
            StoryLine(id: "c1a-4", speaker: .mong, text: "괜찮습니다. 밤에만 눈을 뜨는 새에게 낮의 예절을 요구할 수는 없죠. 저는 몽입니다. 이 서재의 책을 전부 읽었고, 그중 절반은 잊었습니다."),
            StoryLine(id: "c1a-5", speaker: .bori, text: "할머니가 자주 왔었어요?"),
            StoryLine(id: "c1a-6", speaker: .mong, text: "매달 한 번, 반딧불 꽃꿀차를 두 잔 끓여 왔습니다. 제가 잠든 척하면 조용히 두고 갔죠. 그런 사람이 또 오면 좋겠다고 생각한 적은 있습니다.")
        ],
        choices: [
            StoryChoice(
                id: "c1a-c1",
                text: "할머니 이야기, 조금 더 들려줄래요?",
                gains: [AffinityGain(.mong, 5)],
                flag: "ch1.mongStory",
                reply: StoryLine(id: "c1a-c1-r", speaker: .mong, text: "…이야기는 길어집니다. 대신 꽃꿀차를 끓여 오세요. 그럼 밤이 아무리 짧아도 괜찮을 테니.")
            ),
            StoryChoice(
                id: "c1a-c2",
                text: "이 서재, 정말 멋지네요",
                gains: [AffinityGain(.mong, 3)],
                flag: "ch1.mongShelf",
                reply: StoryLine(id: "c1a-c2-r", speaker: .mong, text: "그렇게 말해 준 사람은 할머니 다음으로 두 번째입니다. 창가에 매달아 둔 달조각 향신료 봉지는 가져가도 좋아요. 제가 쓰지 않으니까.")
            )
        ],
        grants: [ItemStack(.moonflakeSpice, 1)],
        unlocksDiary: [],
        closingThought: "서재 문을 닫고 나오자 촛불이 두 번 흔들렸다. 인사 대신일 거라고 생각했다."
    )

    private static let chapterOneBush = StoryScene(
        id: "ch1.bush",
        chapter: .chapterOne,
        title: "덤불의 소문",
        lines: [
            StoryLine(id: "c1b-1", speaker: .rubi, text: "이야— 새 얼굴! 숲이 들썩이겠는데? 소식통인 내가 벌써 세 번째로 네 얘기를 하고 다녔어."),
            StoryLine(id: "c1b-2", speaker: .bori, text: "세 번째…? 하루 만에?"),
            StoryLine(id: "c1b-3", speaker: .rubi, text: "재능이야. 아, 그런데 토리가 내가 제일 예쁘다고 했어? 아니면 제일 시끄럽다고 했어? 둘 다면 좀 서운한데."),
            StoryLine(id: "c1b-4", speaker: .narrator, text: "덤불 뒤에서 이슬방울 베리가 톡, 하고 터지는 소리가 났다. 루비의 꼬리 끝이 살짝 젖어 있었다."),
            StoryLine(id: "c1b-5", speaker: .bori, text: "…루비는, 매일 아침 누구한테 인사해?"),
            StoryLine(id: "c1b-6", speaker: .rubi, text: "…아무한테도. 다들 내가 시끄러우니까 피하거든. 근데 너는 안 피했어. 그래서 내가 오늘 세 번 얘기한 거야.")
        ],
        choices: [
            StoryChoice(
                id: "c1b-c1",
                text: "내일 아침에도 인사하러 올게",
                gains: [AffinityGain(.rubi, 5)],
                flag: "ch1.rubiMorning",
                reply: StoryLine(id: "c1b-c1-r", speaker: .rubi, text: "진짜? 그럼 나 안 피할 자신 있어? …좋아, 이슬방울 베리 바구니는 내가 채워 줄게.")
            ),
            StoryChoice(
                id: "c1b-c2",
                text: "소문 좀 그만 퍼뜨려 줄래?",
                gains: [AffinityGain(.rubi, 2)],
                flag: "ch1.rubiQuiet",
                reply: StoryLine(id: "c1b-c2-r", speaker: .rubi, text: "알겠어, 알겠어. 대신 진짜 중요한 소식만 옮길게. 이 숲에서 제일 중요한 건 결국 누가 뭘 먹고 싶어 하는지니까.")
            )
        ],
        grants: [ItemStack(.dewberry, 2)],
        unlocksDiary: [],
        closingThought: "돌아오는 길에 발끝에 이슬방울 베리가 굴러왔다. 루비가 일부러 굴린 것 같았다."
    )

    // MARK: - 2장

    private static let chapterTwoGarden = StoryScene(
        id: "ch2.garden",
        chapter: .chapterTwo,
        title: "정원의 고슴도치",
        lines: [
            StoryLine(id: "c2a-1", speaker: .narrator, text: "오두막 뒤편, 누가 정성껏 가꾼 작은 밭이 있었다. 이름표가 꽂힌 화분이 서른 개쯤 된다."),
            StoryLine(id: "c2a-2", speaker: .narrator, text: "잎사귀 뒤에서 무언가 바스락했다. 고슴도치가 반쯤 숨은 채 이쪽을 보고 있었다."),
            StoryLine(id: "c2a-3", speaker: .bori, text: "송이야? 토리가 말했어. 이 정원을 만든 사람이 너라고."),
            StoryLine(id: "c2a-4", speaker: .songi, text: "…(끄덕)"),
            StoryLine(id: "c2a-5", speaker: .bori, text: "별이끼 버섯이 이렇게 크게 자랐네. 별이 진 다음 날에만 핀다던데, 맞아?"),
            StoryLine(id: "c2a-6", speaker: .songi, text: "…맞아. 근데 이름은 아직 안 붙였어. 이름을 붙이면, 떠날 때 아파서."),
            StoryLine(id: "c2a-7", speaker: .narrator, text: "고슴도치가 잎 뒤에서 조금 나왔다. 등에 걸린 나뭇잎이 아직 젖어 있었다.")
        ],
        choices: [
            StoryChoice(
                id: "c2a-c1",
                text: "그럼 우리, 하나씩 이름을 붙여 보자",
                gains: [AffinityGain(.songi, 6)],
                flag: "ch2.naming",
                reply: StoryLine(id: "c2a-c1-r", speaker: .songi, text: "…하나씩? 같이? …그럼 제일 큰 건, ‘비둘기’라고 할래. 별이 진 다음에 자꾸 와서.")
            ),
            StoryChoice(
                id: "c2a-c2",
                text: "옆에 그냥 앉아 있을게. 말 안 해도 돼",
                gains: [AffinityGain(.songi, 4)],
                flag: "ch2.sitting",
                reply: StoryLine(id: "c2a-c2-r", speaker: .songi, text: "…(한참 뒤) 이거, 먹어. 별이끼 버섯. 아직 이름은 없지만, 별 맛은 나.")
            )
        ],
        grants: [ItemStack(.starMossShroom, 2)],
        unlocksDiary: [],
        closingThought: "돌아설 때 등 뒤에서 아주 작은 목소리로 ‘안녕’이라는 소리가 났다. 못 들은 척했다."
    )

    private static let chapterTwoKitchen = StoryScene(
        id: "ch2.kitchen",
        chapter: .chapterTwo,
        title: "첫 번째 솥단지",
        lines: [
            StoryLine(id: "c2b-1", speaker: .narrator, text: "수첩의 첫 장을 폈다. 할머니 글씨가 연필로 눌려 있었다."),
            StoryLine(id: "c2b-2", speaker: .bori, text: "‘재료는 두세 가지면 충분하다. 불은 재촉하지 않는다. 손님은 배고플 때 데려온다.’"),
            StoryLine(id: "c2b-3", speaker: .tori, text: "이거! 이 조합! 이슬방울 베리 두 알. 할머니 잼 냄새 나잖아."),
            StoryLine(id: "c2b-4", speaker: .bori, text: "부엌에 베리가 두 알 남아 있어. 첫 잼은 이걸로 담가 볼까?"),
            StoryLine(id: "c2b-5", speaker: .tori, text: "두 알이면 딱이야. 하나는 솥에, 하나는 마지막에 톡. 더 담그려면 채집하러 나가야 해. 재료는 다 숲에 있고, 떨어지는 걸 잘 받아야 하니까."),
            StoryLine(id: "c2b-6", speaker: .bori, text: "받는 건 자신 있어. 대신 불 조절은 도와줘."),
            StoryLine(id: "c2b-7", speaker: .tori, text: "…너, 생각보다 쓸 만한 애다.")
        ],
        choices: [
            StoryChoice(
                id: "c2b-c1",
                text: "같이 만들어 보자. 첫 잼은 같이",
                gains: [AffinityGain(.tori, 5), AffinityGain(.songi, 1)],
                flag: "ch2.cookTogether",
                reply: StoryLine(id: "c2b-c1-r", speaker: .tori, text: "좋아! 내가 베리 씻을게. 아, 근데 물은 좀 적게. 이슬방울 베리는 물을 먹으면 반짝임이 지워지니까.")
            ),
            StoryChoice(
                id: "c2b-c2",
                text: "내가 먼저 한 번 해 볼게",
                gains: [AffinityGain(.tori, 2)],
                flag: "ch2.cookAlone",
                reply: StoryLine(id: "c2b-c2-r", speaker: .tori, text: "뭐, 그럼 나는 옆에서 불만 볼게. 대신 졸면 내가 다 먹는다? 아니, 그것도 좀…")
            )
        ],
        grants: [ItemStack(.moonflakeSpice, 1)],
        unlocksDiary: [],
        closingThought: "솥단지가 끓기 시작했다. 숲에서 처음으로, 이 집의 불이 제 일을 했다."
    )

    // MARK: - 3장

    private static let chapterThreeWishes = StoryScene(
        id: "ch3.wishes",
        chapter: .chapterThree,
        title: "네 개의 소원",
        lines: [
            StoryLine(id: "c3a-1", speaker: .narrator, text: "오두막 식탁에 다섯 개의 컵이 놓였다. 하나는 할머니 자리였는데, 아무도 그걸 치우자고 하지 않았다."),
            StoryLine(id: "c3a-2", speaker: .tori, text: "축제는 다음 보름에. 별이 제일 많이 뜨는 밤이야. 근데 축제는 그냥 열면 안 되고, 네 사람 소원이 모여야 한대."),
            StoryLine(id: "c3a-3", speaker: .mong, text: "소원이라. 저는 별이 창문으로 한 번 더 들어오는 밤이면 충분합니다."),
            StoryLine(id: "c3a-4", speaker: .songi, text: "…정원에, 이름을 붙여 주는 사람. 그게 소원이야."),
            StoryLine(id: "c3a-5", speaker: .rubi, text: "나는 노래! 숲 전체가 같이 부르는 노래. 아, 근데 다들 음치는 아니지?"),
            StoryLine(id: "c3a-6", speaker: .tori, text: "나는 유성우 베리 콩포트. 잔뜩 끓여서 누구랑 나눠 먹는 저녁. 혼자 먹으면 그냥 단 거잖아."),
            StoryLine(id: "c3a-7", speaker: .bori, text: "…그럼 다섯 번째 소원은 내가 할게. 이 식탁에 다섯 명이 앉는 것.")
        ],
        choices: [
            StoryChoice(
                id: "c3a-c1",
                text: "토리, 콩포트 끓이는 건 내가 도울게",
                gains: [AffinityGain(.tori, 6)],
                flag: "ch3.helpTori",
                reply: StoryLine(id: "c3a-c1-r", speaker: .tori, text: "진짜? 그럼 베리는 내가 제일 좋은 걸로 골라 올게. 내가 고르는 건 틀린 적이 없어.")
            ),
            StoryChoice(
                id: "c3a-c2",
                text: "송이, 정원 이름은 같이 짓자",
                gains: [AffinityGain(.songi, 6)],
                flag: "ch3.helpSongi",
                reply: StoryLine(id: "c3a-c2-r", speaker: .songi, text: "…같이. 그럼, 정원 이름은 ‘다섯 컵’으로 할래. 오늘 컵이 다섯 개라서.")
            ),
            StoryChoice(
                id: "c3a-c3",
                text: "몽, 서재 창문을 고쳐 줄게",
                gains: [AffinityGain(.mong, 6)],
                flag: "ch3.helpMong",
                reply: StoryLine(id: "c3a-c3-r", speaker: .mong, text: "창문은 고칠 필요가 없습니다. 다만… 축제 날, 제가 잠들지 않게 옆에 앉아 주세요. 그거면 됩니다.")
            ),
            StoryChoice(
                id: "c3a-c4",
                text: "루비, 노래를 가르쳐 줘",
                gains: [AffinityGain(.rubi, 6)],
                flag: "ch3.helpRubi",
                reply: StoryLine(id: "c3a-c4-r", speaker: .rubi, text: "드디어! 내 노래를 배우는 사람이 생겼어! 가사는 짧아. ‘불을 켜자, 아직 배고프니까’ — 어때, 좋지?")
            )
        ],
        grants: [
            ItemStack(.dewberry, 1),
            ItemStack(.fireflyNectar, 1),
            ItemStack(.starMossShroom, 1),
            ItemStack(.moonflakeSpice, 1)
        ],
        unlocksDiary: [],
        closingThought: "컵 다섯 개가 달빛을 받아 같은 색으로 빛났다. 소원이 모이기 시작한 것 같았다."
    )

    private static let chapterThreeLanterns = StoryScene(
        id: "ch3.lanterns",
        chapter: .chapterThree,
        title: "등불을 만드는 밤",
        lines: [
            StoryLine(id: "c3b-1", speaker: .narrator, text: "축제 전날 밤. 오두막 마루에 유리병이 스물네 개 놓이고, 그 안에 달조각 향신료가 한 꼬집씩 들어갔다."),
            StoryLine(id: "c3b-2", speaker: .mong, text: "이 병은 제가 맡겠습니다. 밤에 하는 일은 익숙하니까요. 대신 낮에 할 일을 하나 부탁해도 될까요."),
            StoryLine(id: "c3b-3", speaker: .bori, text: "뭐든. 말해 봐."),
            StoryLine(id: "c3b-4", speaker: .mong, text: "축제가 끝나도, 이 집에 불이 켜져 있었으면 합니다. 제가 잠들지 않아도 들를 수 있게요."),
            StoryLine(id: "c3b-5", speaker: .rubi, text: "아! 나도! 나는 축제 다음 날 아침에도 문 앞에서 노래할 거야. 시끄럽다고 쫓아내지 마."),
            StoryLine(id: "c3b-6", speaker: .songi, text: "…나는, 화분 두 개를 더 심을 거야. 문 앞에. 들어올 때 보이게."),
            StoryLine(id: "c3b-7", speaker: .tori, text: "나는… 잼을 한 항아리 더 담글 거야. 축제에서 다 먹으면 내일이 없잖아.")
        ],
        choices: [
            StoryChoice(
                id: "c3b-c1",
                text: "그럼 내일 아침 메뉴도 정해 두자",
                gains: [AffinityGain(.tori, 3), AffinityGain(.songi, 3), AffinityGain(.mong, 3), AffinityGain(.rubi, 3)],
                flag: "ch3.nextMorning",
                reply: StoryLine(id: "c3b-c1-r", speaker: .rubi, text: "좋아! 내일 아침은 노래로 시작하는 거야. 그리고 콩포트. 그리고 잼. 그리고… 배고파지네.")
            ),
            StoryChoice(
                id: "c3b-c2",
                text: "황금 보름달 잼을 담글 거야",
                gains: [AffinityGain(.rubi, 4), AffinityGain(.mong, 2)],
                flag: "ch3.cakePlan",
                reply: StoryLine(id: "c3b-c2-r", speaker: .mong, text: "황금 보름달 잼이라. 그럼 뚜껑은 축제가 시작할 때까지 열지 마세요. 달이 항아리 안에서 떠오르는 건, 처음 열 때 한 번뿐이니까.")
            )
        ],
        grants: [ItemStack(.moonflakeSpice, 1)],
        unlocksDiary: [],
        closingThought: "병 스물네 개가 마루에 늘어섰다. 바람이 지나갈 때마다 작은 별이 스물네 번 흔들렸다."
    )

    // MARK: - 에필로그

    private static let epilogueNight = StoryScene(
        id: "epilogue.night",
        chapter: .epilogue,
        title: "별빛 아래에서",
        lines: [
            StoryLine(id: "e1-1", speaker: .narrator, text: "보름. 축제터에 스물네 개의 등불이 걸리고, 식탁에는 잼과 콩포트와 젤리가 놓였다. 가운데에는 황금 보름달 잼 한 항아리가 있다."),
            StoryLine(id: "e1-2", speaker: .tori, text: "…이거, 할머니 잼이랑 똑같은 냄새야. 어떻게 알았어?"),
            StoryLine(id: "e1-3", speaker: .bori, text: "수첩에 적혀 있었어. ‘손님은 배고플 때 데려온다.’"),
            StoryLine(id: "e1-4", speaker: .songi, text: "정원 이름, 마음에 들어. ‘다섯 컵’. …매일 다섯 개를 씻을 거야."),
            StoryLine(id: "e1-5", speaker: .mong, text: "별이 들어왔습니다. 창문이 아니라, 이 자리로."),
            StoryLine(id: "e1-6", speaker: .rubi, text: "자, 노래! ‘불을 켜자, 아직 배고프니까—’ 다 같이!"),
            StoryLine(id: "e1-7", speaker: .narrator, text: "숲이 스스로 불을 밝혔다. 누가 시켜서가 아니라, 다섯 사람이 같은 식탁에 앉았기 때문에.")
        ],
        choices: [
            StoryChoice(
                id: "e1-c1",
                text: "네 사람 모두에게 고맙다고 말한다",
                gains: [AffinityGain(.tori, 4), AffinityGain(.songi, 4), AffinityGain(.mong, 4), AffinityGain(.rubi, 4)],
                flag: "epilogue.thanks",
                reply: StoryLine(id: "e1-c1-r", speaker: .tori, text: "고맙긴. 우리가 더 고마운데. …야, 잼 한 숟갈 더 먹어. 오늘은 세어 보지 마.")
            ),
            StoryChoice(
                id: "e1-c2",
                text: "아무 말 없이 손을 내민다",
                gains: [AffinityGain(.tori, 3), AffinityGain(.songi, 3), AffinityGain(.mong, 3), AffinityGain(.rubi, 3)],
                flag: "epilogue.hands",
                reply: StoryLine(id: "e1-c2-r", speaker: .narrator, text: "다섯 개의 손이 식탁 위에서 겹쳤다. 아무도 먼저 놓지 않았다.")
            )
        ],
        grants: [],
        unlocksDiary: [ForestDiary.festivalEntryID],
        closingThought: "그날 밤 오두막의 불은 늦게까지 꺼지지 않았다. 다음 날 아침에도, 그다음 날에도."
    )
}
