import XCTest
import AcornForestCore

/// 채집 확률표·달빛 기운·선물 하락폭이 의도한 밸런스대로 움직이는지 확인한다.
final class BalanceTests: XCTestCase {
    private let basicLocations: [ForestLocation] = [.cabinKitchen, .berryPatch, .fireflyPond, .owlLibrary, .festivalGlade]

    // MARK: - 드랍표

    func testEveryDropTableAddsUpTo100() {
        for location in ForestLocation.allCases {
            let total = GatherBalance.totalWeight(of: location.dropTable)
            XCTAssertEqual(total, 100, "\(location.title) 드랍표 합이 100이 아니다")
        }
    }

    func testThreeTierTablesKeepTheStatedShares() {
        for location in [ForestLocation.moonlitGarden, .greenhouse] {
            let shares = GatherBalance.tierShares(of: location.dropTable)
            XCTAssertEqual(shares[.common] ?? 0, GatherBalance.commonShare, accuracy: 0.0001, location.title)
            XCTAssertEqual(shares[.refined] ?? 0, GatherBalance.refinedShare, accuracy: 0.0001, location.title)
            XCTAssertEqual(shares[.rare] ?? 0, GatherBalance.rareShare, accuracy: 0.0001, location.title)
        }
    }

    func testTwoTierTablesKeepRefinedScarce() {
        for location in basicLocations {
            let shares = GatherBalance.tierShares(of: location.dropTable)
            XCTAssertEqual(shares[.rare] ?? 0, 0, accuracy: 0.0001, "\(location.title)에는 희귀 재료가 없다")
            XCTAssertEqual(shares[.refined] ?? 0, GatherBalance.refinedShare, accuracy: 0.0001, location.title)
            XCTAssertEqual(shares[.common] ?? 0, GatherBalance.twoTierCommonShare, accuracy: 0.0001, location.title)
        }
    }

    func testRefinedShareStaysBetween20And25Percent() {
        for location in ForestLocation.allCases {
            let shares = GatherBalance.tierShares(of: location.dropTable)
            let refined = shares[.refined] ?? 0
            XCTAssertTrue(0.20...0.25 ~= refined, "\(location.title) 고급 재료 비율 \(refined)")
        }
    }

    func testDropTablesOnlyHoldIngredientsThatGrowThere() {
        for location in ForestLocation.allCases {
            for drop in location.dropTable {
                if let source = drop.ingredient.sourceLocation {
                    XCTAssertEqual(source, location, "\(drop.ingredient.title)은 \(location.title)에서 나오면 안 된다")
                }
            }
        }
    }

    func testSpiceNoLongerFloodsALocation() {
        // 예전에는 몽의 서재에서 달조각 향신료가 66%였다. 지금은 22%로 묶여 있다.
        var rng = SeededRandom(seed: 4242)
        var spice = 0
        let samples = 3000
        for _ in 0..<samples {
            if GatherBalance.pick(from: ForestLocation.owlLibrary.dropTable, using: &rng) == .moonflakeSpice {
                spice += 1
            }
        }
        let share = Double(spice) / Double(samples)
        XCTAssertEqual(share, GatherBalance.refinedShare, accuracy: 0.03, "실제 뽑기 비율 \(share)")
    }

    func testWeightedPickIsReproducible() {
        var first = SeededRandom(seed: 77)
        var second = SeededRandom(seed: 77)
        let a = (0..<20).map { _ in GatherBalance.pick(from: ForestLocation.berryPatch.dropTable, using: &first) }
        let b = (0..<20).map { _ in GatherBalance.pick(from: ForestLocation.berryPatch.dropTable, using: &second) }
        XCTAssertEqual(a, b)
    }

    func testSessionIsShorterAndSparser() {
        for location in basicLocations {
            let session = GatheringSession(location: location, seed: 5)
            XCTAssertEqual(session.duration, GatherBalance.sessionDuration, accuracy: 0.0001)
            XCTAssertTrue((6...20).contains(session.items.count), "\(location.title) 한 판 \(session.items.count)개")
            XCTAssertEqual(GatherBalance.goldenChance, 0.06, accuracy: 0.0001)
        }
    }

    // MARK: - 달빛 기운

    func testGatheringSpendsOneEnergyAndStopsAtZero() {
        let engine = TestSupport.engine(state: TestSupport.stateWithPrologueDone())
        XCTAssertEqual(engine.state.moonlightEnergy, GatherBalance.maxEnergy)
        for index in 0..<GatherBalance.maxEnergy {
            XCTAssertTrue(engine.startGathering(at: .berryPatch, seed: UInt64(index + 1)))
            XCTAssertEqual(engine.state.moonlightEnergy, GatherBalance.maxEnergy - index - 1)
            TestSupport.catchEverything(engine)
        }
        XCTAssertEqual(engine.state.moonlightEnergy, 0)
        XCTAssertFalse(engine.startGathering(at: .berryPatch, seed: 99))
        XCTAssertTrue(engine.lastMessage.contains("달빛 기운"), engine.lastMessage)
    }

    func testNewDayRefillsEnergy() {
        let engine = TestSupport.engine(state: TestSupport.stateWithPrologueDone())
        for index in 0..<GatherBalance.maxEnergy {
            _ = engine.startGathering(at: .berryPatch, seed: UInt64(index + 1))
            TestSupport.catchEverything(engine)
        }
        XCTAssertEqual(engine.state.moonlightEnergy, 0)
        engine.simulateNextDay()
        XCTAssertEqual(engine.state.moonlightEnergy, GatherBalance.maxEnergy)
        XCTAssertTrue(engine.startGathering(at: .berryPatch, seed: 3))
    }

    func testFocusGivesEnergyBackWithDailyCap() {
        let engine = TestSupport.engine(state: TestSupport.stateWithPrologueDone())
        for index in 0..<GatherBalance.maxEnergy {
            _ = engine.startGathering(at: .berryPatch, seed: UInt64(index + 1))
            TestSupport.catchEverything(engine)
        }
        for attempt in 0..<(GatherBalance.focusEnergyCap + 1) {
            XCTAssertTrue(engine.startFocus(.five, track: .rain), "\(attempt)")
            engine.tickFocus(300)
            _ = engine.finishFocus()
        }
        XCTAssertEqual(engine.state.moonlightEnergy, GatherBalance.focusEnergyCap,
                       "집중으로는 하루 \(GatherBalance.focusEnergyCap)칸까지만 채운다")
        XCTAssertEqual(engine.state.focusRecoveries, GatherBalance.focusEnergyCap)
    }

    func testMailboxGivesEnergyBackWithDailyCap() {
        var state = TestSupport.stateWithPrologueDone()
        for index in 0..<(GatherBalance.letterEnergyCap + 1) {
            state.mailbox.append(MailboxLetter(sender: .tori, day: 900 + index,
                                               gift: ItemStack(.dewberry, 1), note: "선물"))
        }
        let engine = TestSupport.engine(state: state)
        for index in 0..<GatherBalance.maxEnergy {
            _ = engine.startGathering(at: .berryPatch, seed: UInt64(index + 1))
            TestSupport.catchEverything(engine)
        }
        XCTAssertEqual(engine.state.moonlightEnergy, 0)
        for letter in engine.state.mailbox {
            _ = engine.claimLetter(id: letter.id)
        }
        XCTAssertEqual(engine.state.moonlightEnergy, GatherBalance.letterEnergyCap)
        XCTAssertEqual(engine.state.letterRecoveries, GatherBalance.letterEnergyCap)
    }

    func testEnergyNeverGoesAboveMaximum() {
        var state = TestSupport.stateWithPrologueDone()
        state.recoverEnergyFromFocus()
        state.recoverEnergyFromLetter()
        state.recoverEnergyFromOrder()
        XCTAssertEqual(state.moonlightEnergy, GatherBalance.maxEnergy)
    }

    func testEnergyLineShowsFilledMoons() {
        let engine = TestSupport.engine(state: TestSupport.stateWithPrologueDone())
        XCTAssertTrue(engine.energyLine.contains("5/5"))
        _ = engine.startGathering(at: .berryPatch, seed: 1)
        XCTAssertEqual(engine.energyStars.filter { $0 == "●" }.count, GatherBalance.maxEnergy - 1)
        XCTAssertTrue(engine.energyLine.contains("4/5"))
    }

    // MARK: - 여러 날에 걸친 호감도

    func testCloseFriendshipNeedsMoreThanOneDay() {
        // 최애 잼을 완벽하게 만들어도 하루에 단짝이 되지 않는다.
        var state = TestSupport.stockedState([])
        state.addCooked(recipeID: "meteor-berry-compote", quality: .perfect, extraServings: 40)
        let engine = TestSupport.engine(state: state)

        var gains: [Int] = []
        for _ in 0..<4 {
            gains.append(engine.gift(recipeID: "meteor-berry-compote", to: .tori).gain)
        }
        XCTAssertEqual(gains, [15, 8, 5, 2], "같은 날 네 번이면 15·8·5·2로 잦아든다")
        XCTAssertEqual(engine.state.affinityPoints(for: .tori), 30)
        XCTAssertEqual(engine.state.affinityLevel(for: .tori), .greeting, "하루 만에는 단짝이 안 된다")

        engine.simulateNextDay()
        XCTAssertEqual(engine.gift(recipeID: "meteor-berry-compote", to: .tori).gain, 15,
                       "날이 바뀌면 다시 온전히 반가워한다")

        var days = 2
        while engine.state.affinityLevel(for: .tori) < .close && days < 10 {
            engine.simulateNextDay()
            days += 1
            for _ in 0..<6 where engine.state.affinityLevel(for: .tori) < .close {
                _ = engine.gift(recipeID: "meteor-berry-compote", to: .tori)
            }
        }
        XCTAssertGreaterThanOrEqual(days, 2, "단짝은 여러 날에 걸쳐서만 된다")
        XCTAssertEqual(engine.state.affinityLevel(for: .tori), .close)
    }

    func testFullPlaythroughTakesSeveralDays() {
        // 채집·요리·선물을 반복해도 에필로그는 하루 만에 열리지 않는다.
        var state = TestSupport.stockedState([])
        state.markCompleted(.prologue)
        state.markCompleted(.chapterOne)
        state.markCompleted(.chapterTwo)
        state.markCompleted(.chapterThree)
        state.stats.totalCaught = 40
        for recipeID in ["dawn-dew-jam", "firefly-sparkle-jam", "starlight-mist-jam",
                         "cloud-cotton-marmalade", "moonshadow-herb-jelly", ChapterRules.signatureRecipeID] {
            state.addCooked(recipeID: recipeID, quality: .good)
        }
        for character in CharacterID.coreNeighbours {
            state.addCooked(recipeID: character.favoriteRecipeID, quality: .perfect, extraServings: 40)
        }
        let engine = TestSupport.engine(state: state)
        var days = 0
        while !ChapterRules.isUnlocked(.epilogue, in: engine.state) && days < 20 {
            for character in CharacterID.coreNeighbours {
                for _ in 0..<6 where engine.state.affinityLevel(for: character) < .close {
                    let before = engine.state.affinityPoints(for: character)
                    _ = engine.gift(recipeID: character.favoriteRecipeID, to: character)
                    if engine.state.affinityPoints(for: character) == before { break }
                }
            }
            if ChapterRules.isUnlocked(.epilogue, in: engine.state) { break }
            engine.simulateNextDay()
            days += 1
        }
        XCTAssertTrue(ChapterRules.isUnlocked(.epilogue, in: engine.state))
        XCTAssertGreaterThanOrEqual(days, 2, "에필로그는 여러 날에 걸쳐 열린다")
        XCTAssertLessThanOrEqual(days, 8, "그래도 일주일 안에는 손이 닿는다")
    }
}
