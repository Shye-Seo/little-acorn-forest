import XCTest
import AcornForestCore

final class MailboxTests: XCTestCase {
    private func friendlyState() -> GameState {
        var state = TestSupport.stockedState([])
        for character in CharacterID.coreNeighbours {
            state.addAffinity(MailboxSystem.affinityThreshold, to: character)
        }
        return state
    }

    private func firstDayWithLetters(_ state: GameState, within limit: Int = 30) -> Int? {
        for day in 1...limit where !MailboxSystem.letters(forDay: day, state: state, now: TestSupport.fixedDate).isEmpty {
            return day
        }
        return nil
    }

    func testOnlyGreetedNeighboursWrite() {
        XCTAssertTrue(MailboxSystem.eligibleSenders(in: GameEngine.freshState()).isEmpty)
        let state = friendlyState()
        XCTAssertEqual(MailboxSystem.eligibleSenders(in: state).count, 4)
        XCTAssertEqual(MailboxSystem.affinityThreshold, AffinityLevel.greeting.rawValue)
    }

    func testExpansionNeighboursNeedTheGreenhouse() {
        var state = friendlyState()
        state.addAffinity(30, to: .luna)
        XCTAssertFalse(MailboxSystem.eligibleSenders(in: state).contains(.luna))
        state.grant(.greenhouse)
        XCTAssertTrue(MailboxSystem.eligibleSenders(in: state).contains(.luna))
    }

    func testLettersAreStableForTheSameDay() {
        let state = friendlyState()
        let first = MailboxSystem.letters(forDay: 20_261_124, state: state, now: TestSupport.fixedDate)
        let second = MailboxSystem.letters(forDay: 20_261_124, state: state, now: TestSupport.fixedDate)
        XCTAssertEqual(first.map(\.sender), second.map(\.sender))
        XCTAssertEqual(first.map(\.gift), second.map(\.gift))
        XCTAssertLessThanOrEqual(first.count, MailboxSystem.dailyLimit)
    }

    func testSomeDayBringsALetterWithGiftOrNote() throws {
        let state = friendlyState()
        var found: MailboxLetter?
        for day in 1...40 {
            let letters = MailboxSystem.letters(forDay: day, state: state, now: TestSupport.fixedDate)
            if let letter = letters.first(where: { $0.hasGift || $0.hasSecretRecipe }) {
                found = letter
                break
            }
        }
        let letter = try XCTUnwrap(found, "40일 동안 선물이나 쪽지가 담긴 편지가 한 통도 없다")
        XCTAssertFalse(letter.previewLine.isEmpty)
        XCTAssertFalse(letter.title.isEmpty)
    }

    func testSecretNotesTeachOnlyUnlearnedRecipes() throws {
        var state = friendlyState()
        var note: MailboxLetter?
        for day in 1...60 {
            for letter in MailboxSystem.letters(forDay: day, state: state, now: TestSupport.fixedDate) where letter.hasSecretRecipe {
                note = letter
                break
            }
            if note != nil { break }
        }
        let letter = try XCTUnwrap(note)
        let recipeID = try XCTUnwrap(letter.secretRecipeID)
        XCTAssertNotNil(SecretRecipeBook.recipe(id: recipeID))

        state.secretRecipes = SecretRecipeBook.ids
        let gates = MailboxSystem.letters(forDay: 20_261_201, state: state, now: TestSupport.fixedDate)
        XCTAssertFalse(gates.contains { $0.hasSecretRecipe }, "이미 다 배운 뒤에는 쪽지가 오지 않는다")
    }

    func testCheckMailboxIsOncePerDay() {
        let state = friendlyState()
        let engine = TestSupport.engine(state: state, moon: .waning)
        guard let day = firstDayWithLetters(state) else { return XCTFail("편지가 오는 날이 없다") }
        let first = engine.checkMailbox(day: day)
        XCTAssertEqual(engine.state.lastMailCheckDay, day)
        let second = engine.checkMailbox(day: day)
        XCTAssertTrue(second.isEmpty)
        XCTAssertEqual(engine.state.mailbox.count, first.count)
    }

    func testSimulateNextDayDeliversLetters() {
        var state = friendlyState()
        state.lastMailCheckDay = 0
        let engine = TestSupport.engine(state: state, moon: .waning)
        var delivered = 0
        for _ in 0..<10 {
            delivered += engine.simulateNextDay().count
        }
        XCTAssertGreaterThan(delivered, 0)
        XCTAssertGreaterThan(engine.state.debugDayShift, 0)
    }

    func testClaimingGiftAddsIngredients() throws {
        var state = TestSupport.stockedState([])
        let letter = MailboxLetter(sender: .tori,
                                   day: 100,
                                   gift: ItemStack(.dewberry, 2),
                                   note: "선물")
        state.mailbox.append(letter)
        let engine = TestSupport.engine(state: state)
        XCTAssertEqual(engine.mailBadgeCount, 1)

        let claimed = try XCTUnwrap(engine.claimLetter(id: letter.id))
        XCTAssertTrue(claimed.isClaimed)
        XCTAssertEqual(engine.state.count(of: .dewberry), 2)
        XCTAssertEqual(engine.mailBadgeCount, 0)
        XCTAssertNil(engine.claimLetter(id: letter.id), "같은 편지를 두 번 받을 수 없다")
    }

    func testClaimingNoteTeachesASecretRecipe() throws {
        var state = TestSupport.stockedState([
            ItemStack(.dewberry, 1),
            ItemStack(.moonflakeSpice, 1)
        ])
        let letter = MailboxLetter(sender: .mong,
                                   day: 101,
                                   secretRecipeID: SecretRecipeBook.rainyDayID,
                                   note: "쪽지")
        state.mailbox.append(letter)
        let engine = TestSupport.engine(state: state)

        XCTAssertNil(engine.recipePreview(for: [.dewberry, .moonflakeSpice]),
                     "쪽지를 받기 전에는 수첩에 없는 조합이다")
        _ = engine.claimLetter(id: letter.id)
        XCTAssertTrue(engine.state.secretRecipes.contains(SecretRecipeBook.rainyDayID))
        XCTAssertTrue(engine.state.hasDiary(ForestDiary.recipeEntryID(for: SecretRecipeBook.rainyDayID)))
        XCTAssertEqual(engine.recipePreview(for: [.dewberry, .moonflakeSpice])?.id, SecretRecipeBook.rainyDayID)

        XCTAssertTrue(engine.startCooking(ingredients: [.dewberry, .moonflakeSpice]))
        let outcome = engine.finishCooking()
        XCTAssertEqual(outcome?.recipe?.id, SecretRecipeBook.rainyDayID)
    }

    func testMailboxCapacityIsRespected() {
        var state = friendlyState()
        for index in 0..<MailboxSystem.capacity {
            state.mailbox.append(MailboxLetter(sender: .tori, day: 200 + index,
                                               gift: ItemStack(.dewberry, 1), note: "가득"))
        }
        let engine = TestSupport.engine(state: state)
        XCTAssertTrue(engine.checkMailbox(day: 999).isEmpty)
        XCTAssertEqual(engine.state.mailbox.count, MailboxSystem.capacity)
    }

    func testLetterPreviewDescribesWhatIsInside() {
        let gift = MailboxLetter(sender: .rubi, day: 1, gift: ItemStack(.fireflyNectar, 1), note: "")
        XCTAssertTrue(gift.previewLine.contains("반딧불 꽃꿀"))
        let note = MailboxLetter(sender: .songi, day: 1, secretRecipeID: SecretRecipeBook.firstFrostID, note: "")
        XCTAssertTrue(note.previewLine.contains("레시피"))
        let plain = MailboxLetter(sender: .songi, day: 1, note: "")
        XCTAssertTrue(plain.isEmpty)
        XCTAssertEqual(plain.claimTitle, "받기")
    }
}
