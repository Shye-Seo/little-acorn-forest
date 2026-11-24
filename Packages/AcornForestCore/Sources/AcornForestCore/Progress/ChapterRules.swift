import Foundation

/// 챕터 해금 조건 한 줄. 지도 화면의 체크리스트로도 쓰인다.
public struct ChapterGoal: Sendable, Equatable, Identifiable {
    public let id: String
    public let text: String
    public let isMet: Bool

    public init(id: String, text: String, isMet: Bool) {
        self.id = id
        self.text = text
        self.isMet = isMet
    }
}

/// 어떤 챕터를 열려면 무엇이 되어 있어야 하는가.
/// 여기 조건은 모두 '실제 플레이로만' 채울 수 있게 잡았다(채집·요리·선물).
///
/// 한 판에 몰아서 끝나지 않도록 문턱을 올려 두었다.
/// - 2장: 채집 10개 + 서로 다른 잼 2가지
/// - 3장: 네 이웃과 인사하는 사이 + 서로 다른 잼 5가지
/// - 에필로그: 황금 보름달 잼 + 네 이웃 모두 단짝(90)
public enum ChapterRules {
    public static let closeAffinityThreshold = AffinityLevel.close.rawValue
    /// 2장을 열기 위해 주워야 하는 재료 수.
    public static let chapterTwoCatchGoal = 10
    /// 2장을 열기 위해 담가야 하는 서로 다른 잼 수.
    public static let chapterTwoRecipeGoal = 2
    /// 3장을 열기 위해 담가야 하는 서로 다른 잼 수.
    public static let chapterThreeRecipeGoal = 5
    /// 에필로그의 시그니처 잼.
    public static let signatureRecipeID = "golden-fullmoon-jam"

    public static func isUnlocked(_ chapter: StoryChapter, in state: GameState) -> Bool {
        switch chapter {
        case .prologue:
            return true
        case .chapterOne:
            return state.status(of: .prologue) == .completed
        case .chapterTwo:
            guard state.status(of: .chapterOne) == .completed else { return false }
            return state.stats.totalCaught >= chapterTwoCatchGoal
                && state.cookedRecipeCount >= chapterTwoRecipeGoal
        case .chapterThree:
            guard state.status(of: .chapterTwo) == .completed else { return false }
            let greeted = CharacterID.coreNeighbours.filter { state.affinityPoints(for: $0) >= AffinityLevel.greeting.rawValue }
            return greeted.count == CharacterID.coreNeighbours.count
                && state.cookedRecipeCount >= chapterThreeRecipeGoal
        case .epilogue:
            guard state.status(of: .chapterThree) == .completed else { return false }
            let closeCount = CharacterID.coreNeighbours.filter { state.affinityPoints(for: $0) >= closeAffinityThreshold }.count
            return state.cookedRecipeIDs.contains(signatureRecipeID)
                && closeCount == CharacterID.coreNeighbours.count
        }
    }

    public static func goals(for chapter: StoryChapter, in state: GameState) -> [ChapterGoal] {
        let previousDone: (StoryChapter) -> Bool = { state.status(of: $0) == .completed }

        switch chapter {
        case .prologue:
            return [
                ChapterGoal(id: "prologue-read", text: "할머니의 오두막 문을 연다", isMet: state.status(of: .prologue) != .locked)
            ]
        case .chapterOne:
            return [
                ChapterGoal(id: "ch1-prologue", text: "프롤로그를 마친다", isMet: previousDone(.prologue))
            ]
        case .chapterTwo:
            return [
                ChapterGoal(id: "ch2-chapter1", text: "1장을 마친다", isMet: previousDone(.chapterOne)),
                ChapterGoal(
                    id: "ch2-gather",
                    text: "재료를 \(chapterTwoCatchGoal)개 이상 줍는다 (\(min(state.stats.totalCaught, chapterTwoCatchGoal))/\(chapterTwoCatchGoal))",
                    isMet: state.stats.totalCaught >= chapterTwoCatchGoal
                ),
                ChapterGoal(
                    id: "ch2-cook",
                    text: "서로 다른 잼 \(chapterTwoRecipeGoal)가지를 담근다 (\(min(state.cookedRecipeCount, chapterTwoRecipeGoal))/\(chapterTwoRecipeGoal))",
                    isMet: state.cookedRecipeCount >= chapterTwoRecipeGoal
                )
            ]
        case .chapterThree:
            let greeted = CharacterID.coreNeighbours.filter { state.affinityPoints(for: $0) >= AffinityLevel.greeting.rawValue }.count
            return [
                ChapterGoal(id: "ch3-chapter2", text: "2장을 마친다", isMet: previousDone(.chapterTwo)),
                ChapterGoal(id: "ch3-greet", text: "네 이웃과 인사하는 사이가 된다 (\(greeted)/4)", isMet: greeted == 4),
                ChapterGoal(
                    id: "ch3-recipes",
                    text: "서로 다른 잼 \(chapterThreeRecipeGoal)가지를 만든다 (\(min(state.cookedRecipeCount, chapterThreeRecipeGoal))/\(chapterThreeRecipeGoal))",
                    isMet: state.cookedRecipeCount >= chapterThreeRecipeGoal
                )
            ]
        case .epilogue:
            let closeCount = CharacterID.coreNeighbours.filter { state.affinityPoints(for: $0) >= closeAffinityThreshold }.count
            return [
                ChapterGoal(id: "epi-chapter3", text: "3장을 마친다", isMet: previousDone(.chapterThree)),
                ChapterGoal(id: "epi-moon-jam", text: "황금 보름달 잼을 담근다", isMet: state.cookedRecipeIDs.contains(signatureRecipeID)),
                ChapterGoal(id: "epi-close", text: "네 이웃 모두와 단짝이 된다 (\(closeCount)/4)", isMet: closeCount == 4)
            ]
        }
    }

    /// 다음에 플레이할 수 있는 챕터. 모두 끝났으면 nil.
    public static func nextPlayableChapter(in state: GameState) -> StoryChapter? {
        StoryChapter.ordered.first { state.status(of: $0).isPlayable }
    }

    public static func nextLockedChapterAfterCurrent(in state: GameState) -> StoryChapter? {
        StoryChapter.ordered.first {
            state.status(of: $0) == .locked && isUnlockedWithoutStatus($0, in: state)
        }
    }

    /// 상태 갱신 전에도 계산할 수 있는 해금 판정.
    static func isUnlockedWithoutStatus(_ chapter: StoryChapter, in state: GameState) -> Bool {
        switch chapter {
        case .prologue:
            return true
        case .chapterOne:
            return state.status(of: .prologue) == .completed
        case .chapterTwo:
            return state.status(of: .chapterOne) == .completed
                && state.stats.totalCaught >= chapterTwoCatchGoal
                && state.cookedRecipeCount >= chapterTwoRecipeGoal
        case .chapterThree:
            let greeted = CharacterID.coreNeighbours.filter { state.affinityPoints(for: $0) >= AffinityLevel.greeting.rawValue }.count
            return state.status(of: .chapterTwo) == .completed
                && greeted == 4
                && state.cookedRecipeCount >= chapterThreeRecipeGoal
        case .epilogue:
            let closeCount = CharacterID.coreNeighbours.filter { state.affinityPoints(for: $0) >= closeAffinityThreshold }.count
            return state.status(of: .chapterThree) == .completed
                && state.cookedRecipeIDs.contains(signatureRecipeID)
                && closeCount == 4
        }
    }

    /// 챕터가 끝났을 때 열리는 다음 챕터의 안내 문구.
    public static func unlockMessage(for chapter: StoryChapter, in state: GameState) -> String {
        guard let next = chapter.next else {
            return "이야기가 모두 끝났어요. 숲은 이제 보리의 집이 되었습니다."
        }
        if isUnlocked(next, in: state) {
            return "\(next.shortTitle)이 열렸어요. 숲 지도에서 이어서 걸어가 보세요."
        }
        let unmet = goals(for: next, in: state).filter { !$0.isMet }.map(\.text)
        return "\(next.shortTitle)은 아직 열리지 않았어요. " + unmet.joined(separator: " · ")
    }
}
