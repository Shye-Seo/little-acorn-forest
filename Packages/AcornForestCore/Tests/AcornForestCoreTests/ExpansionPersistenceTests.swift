import XCTest
import AcornForestCore

final class ExpansionPersistenceTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_795_388_400)

    func testExpansionStateSurvivesRoundTrip() throws {
        var state = GameState(startedAt: fixedDate)
        state.add(GameState.startingBasket)
        state.setStatus(.available, for: .prologue)
        state.grant(.greenhouse)
        state.grant(.bottleWorkshop)
        state.grant(.asmrTracks)
        state.cabinStyle = .mossLamp
        state.addCooked(recipeID: "dawn-dew-jam", quality: .perfect, blessingTag: "blessing.fullMoon", extraServings: 1)
        _ = state.placeJar(CustomJamJar(recipeID: "dawn-dew-jam",
                                        bottle: .crystal,
                                        cap: .starCap,
                                        ribbon: .moonflake,
                                        label: "보름의 병",
                                        madeAt: fixedDate,
                                        moonPhase: .fullMoon))
        state.mailbox.append(MailboxLetter(sender: .tori, day: 20_261_124,
                                           deliveredAt: fixedDate,
                                           gift: ItemStack(.dewberry, 1), note: "안부"))
        state.secretRecipes = [SecretRecipeBook.rainyDayID]
        state.talkedCharacters = [.luna]
        state.fireflyDust = 12
        state.focusSessions = 2
        state.focusMinutes = 30
        state.debugMoonOverride = .fullMoon
        state.normalize()

        let data = try SaveCodec.encode(SaveFile(state: state, savedAt: fixedDate))
        let restored = try SaveCodec.decode(data)

        XCTAssertEqual(restored.state, state)
        XCTAssertEqual(restored.state.purchasedPacks.count, 3)
        XCTAssertEqual(restored.state.cabinStyle, .mossLamp)
        XCTAssertEqual(restored.state.jars.first?.bottle, .crystal)
        XCTAssertEqual(restored.state.jars.first?.label, "보름의 병")
        XCTAssertEqual(restored.state.mailbox.count, 1)
        XCTAssertEqual(restored.state.fireflyDust, 12)
        XCTAssertEqual(restored.state.talkedCharacters, [.luna])
        XCTAssertEqual(restored.state.debugMoonOverride, .fullMoon)
        XCTAssertEqual(restored.state.servings(of: "dawn-dew-jam"), 2)
    }

    func testLegacySaveWithoutExpansionKeysStillOpens() throws {
        var state = GameEngine.freshState()
        state.addCooked(recipeID: "dawn-dew-jam", quality: .good)
        state.addAffinity(24, to: .tori)
        let data = try SaveCodec.encode(SaveFile(state: state, savedAt: fixedDate))

        var root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var stateDict = try XCTUnwrap(root["state"] as? [String: Any])
        let newKeys = ["jars", "mailbox", "lastMailCheckDay", "purchasedPacks", "cabinStyle",
                       "fireflyDust", "focusSessions", "focusMinutes", "secretRecipes",
                       "talkedCharacters", "debugMoonOverride", "debugDayShift",
                       "moonlightEnergy", "energyDay", "focusRecoveries", "letterRecoveries",
                       "giftDay", "giftCounts", "orderPoints", "orderStreak", "bestOrderStreak",
                       "orders", "orderTrophies"]
        for key in newKeys {
            stateDict.removeValue(forKey: key)
        }
        var cooked = try XCTUnwrap(stateDict["cooked"] as? [[String: Any]])
        for index in cooked.indices {
            cooked[index].removeValue(forKey: "blessingTags")
        }
        stateDict["cooked"] = cooked
        root["state"] = stateDict
        let legacy = try JSONSerialization.data(withJSONObject: root)

        let restored = try SaveCodec.decode(legacy)
        XCTAssertEqual(restored.state.jars.count, 0)
        XCTAssertEqual(restored.state.mailbox.count, 0)
        XCTAssertEqual(restored.state.purchasedPacks.count, 0)
        XCTAssertEqual(restored.state.cabinStyle, .attic)
        XCTAssertEqual(restored.state.fireflyDust, 0)
        XCTAssertEqual(restored.state.servings(of: "dawn-dew-jam"), 1)
        XCTAssertEqual(restored.state.affinityPoints(for: .tori), 24)
        XCTAssertEqual(restored.state.record(for: "dawn-dew-jam")?.blessingTags, [])
        XCTAssertEqual(restored.state.moonlightEnergy, GatherBalance.maxEnergy, "예전 저장 파일은 기운을 다 채워 열린다")
        XCTAssertTrue(restored.state.orders.isEmpty)
        XCTAssertEqual(restored.state.orderPoints, 0)
    }

    func testNormalizeRepairsExtensionState() {
        var state = GameState()
        state.purchasedPacks = [.greenhouse, .greenhouse]
        state.secretRecipes = ["secret.unknown", SecretRecipeBook.firstFrostID]
        state.cabinStyle = .starWall
        state.talkedCharacters = [.luna, .luna]
        state.fireflyDust = -4
        state.focusMinutes = -10
        state.jars = [
            CustomJamJar(recipeID: "dawn-dew-jam", slot: 2),
            CustomJamJar(recipeID: "dawn-dew-jam", slot: 2)
        ]
        state.normalize()
        XCTAssertEqual(state.purchasedPacks, [.greenhouse])
        XCTAssertEqual(state.secretRecipes, [SecretRecipeBook.firstFrostID])
        XCTAssertEqual(state.talkedCharacters, [.luna])
        XCTAssertEqual(state.cabinStyle, .attic, "스킨을 사지 않았으면 기본 오두막")
        XCTAssertEqual(state.fireflyDust, 0)
        XCTAssertEqual(state.focusMinutes, 0)
        XCTAssertEqual(Set(state.jars.map(\.slot)), [0, 2])
    }

    func testNewerSaveVersionIsRejected() {
        var root: [String: Any] = [:]
        root["formatVersion"] = 99
        root["savedAt"] = ISO8601DateFormatter().string(from: fixedDate)
        root["state"] = [String: Any]()
        XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: root))) { error in
            XCTAssertEqual(error as? SaveError, .unsupportedVersion(99))
        }
    }

    func testEngineRestoresJarsAndMailboxAfterRelaunch() {
        let store = InMemorySaveStore()
        var state = GameEngine.freshState()
        state.addCooked(recipeID: "dawn-dew-jam", quality: .good, extraServings: 1)
        state.grant(.bottleWorkshop)
        let engine = GameEngine(saveStore: store, state: state)
        let decoration = engine.decorateJar(recipeID: "dawn-dew-jam",
                                            bottle: .gourd,
                                            cap: .checkCloth,
                                            ribbon: .berry,
                                            label: "첫 병")
        XCTAssertTrue(decoration.succeeded)
        engine.simulateNextDay()

        let reopened = GameEngine(saveStore: store)
        XCTAssertTrue(reopened.loadGame())
        XCTAssertTrue(reopened.owns(.bottleWorkshop))
        XCTAssertEqual(reopened.shelfJars.count, 1)
        XCTAssertEqual(reopened.shelfJars.first?.bottle, .gourd)
        XCTAssertEqual(reopened.shelfJars.first?.label, "첫 병")
    }

    func testExpandedDiaryProgressIsCountedSeparately() {
        var state = GameEngine.freshState()
        XCTAssertEqual(state.diaryProgress.total, 26)
        XCTAssertEqual(state.expandedDiaryProgress.total, ForestDiary.expandedCount)
        XCTAssertGreaterThan(state.expandedDiaryProgress.total, 0)
        state.unlockDiary(ForestDiary.recipeEntryID(for: GreenhouseRecipes.springID))
        XCTAssertEqual(state.expandedDiaryProgress.unlocked, 1)
        XCTAssertEqual(state.diaryProgress.unlocked, 0, "확장 기록은 본편 진행도를 흔들지 않는다")
    }
}
