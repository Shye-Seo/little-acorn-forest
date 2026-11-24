import XCTest
import AcornForestCore

final class FocusTimerTests: XCTestCase {
    func testDurationsAndLabels() {
        XCTAssertEqual(FocusDuration.allCases.map(\.rawValue), [5, 15, 25])
        XCTAssertEqual(FocusDuration.five.seconds, 300, accuracy: 0.001)
        XCTAssertEqual(FocusDuration.twentyFive.seconds, 1500, accuracy: 0.001)
    }

    func testSessionCountsDownAndFinishes() {
        var session = FocusSession(duration: .five, track: .rain)
        XCTAssertEqual(session.timeLabel, "05:00")
        XCTAssertFalse(session.isFinished)
        session.tick(120)
        XCTAssertEqual(session.remaining, 180, accuracy: 0.001)
        XCTAssertEqual(session.progress, 0.4, accuracy: 0.001)
        XCTAssertEqual(session.timeLabel, "03:00")
        session.tick(400)
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.remaining, 0, accuracy: 0.001)
        session.tick(10)
        XCTAssertEqual(session.elapsed, 300, accuracy: 0.001, "끝난 뒤에는 더 흐르지 않는다")
    }

    func testRewardGrowsWithLengthAndPack() {
        let short = FocusRules.reward(for: .five, track: .rain, ownsASMRPack: false)
        XCTAssertEqual(short.fireflyDust, 1)
        XCTAssertEqual(short.multiplier, 1)
        XCTAssertEqual(short.ingredients.first(where: { $0.ingredient == .starMossShroom })?.count, 1)

        let long = FocusRules.reward(for: .twentyFive, track: .nightInsects, ownsASMRPack: true)
        XCTAssertEqual(long.fireflyDust, 10)
        XCTAssertEqual(long.multiplier, 2)
        XCTAssertEqual(long.ingredients.first(where: { $0.ingredient == .starMossShroom })?.count, 10)
        XCTAssertTrue(long.isDoubled)
        XCTAssertTrue(long.message.contains("ASMR"))
    }

    func testFullMoonAddsMoonlitDew() {
        let reward = FocusRules.reward(for: .fifteen, track: .hearth, ownsASMRPack: false, isFullMoon: true)
        XCTAssertEqual(reward.ingredients.first(where: { $0.ingredient == .moonlitDew })?.count, 1)
        XCTAssertTrue(reward.message.contains("보름달"))
    }

    func testAmbientTracksSplitFreeAndPaid() {
        XCTAssertEqual(AmbientTrack.tracks(ownsPack: false).count, 3)
        XCTAssertEqual(AmbientTrack.tracks(ownsPack: true).count, 5)
        XCTAssertTrue(AmbientTrack.rain.isFree)
        XCTAssertEqual(AmbientTrack.nightInsects.requiredPack, .asmrTracks)
        XCTAssertEqual(AmbientTrack.windChime.requiredPack, .asmrTracks)
    }

    func testEngineRefusesLockedTrack() {
        let engine = TestSupport.engine()
        XCTAssertFalse(engine.startFocus(.five, track: .nightInsects))
        XCTAssertNil(engine.focusSession)
        XCTAssertTrue(engine.lastMessage.contains("ASMR"))
        XCTAssertTrue(engine.startFocus(.five, track: .rain))
        XCTAssertNotNil(engine.focusSession)
    }

    func testFinishingFocusGrantsRewards() {
        let engine = TestSupport.engine()
        XCTAssertTrue(engine.startFocus(.five, track: .hearth))
        var steps = 0
        while let session = engine.focusSession, !session.isFinished, steps < 400 {
            steps += 1
            engine.tickFocus(1)
        }
        let reward = engine.finishFocus()
        XCTAssertNotNil(reward)
        XCTAssertEqual(engine.state.fireflyDust, 1)
        XCTAssertEqual(engine.state.focusSessions, 1)
        XCTAssertEqual(engine.state.focusMinutes, 5)
        XCTAssertEqual(engine.state.count(of: .starMossShroom), 1)
        XCTAssertNil(engine.focusSession)
    }

    func testEarlyFinishGivesNothing() {
        let engine = TestSupport.engine()
        XCTAssertTrue(engine.startFocus(.fifteen, track: .simmer))
        engine.tickFocus(60)
        XCTAssertNil(engine.finishFocus())
        XCTAssertEqual(engine.state.fireflyDust, 0)
        engine.cancelFocus()
        XCTAssertNil(engine.focusSession)
    }

    func testPackDoublesTheSameSessionReward() {
        let plain = TestSupport.engine()
        XCTAssertTrue(plain.startFocus(.twentyFive, track: .rain))
        plain.tickFocus(1500)
        let plainReward = plain.finishFocus()
        XCTAssertEqual(plainReward?.fireflyDust, 5)

        var state = TestSupport.stockedState([])
        state.grant(.asmrTracks)
        let packed = TestSupport.engine(state: state)
        XCTAssertTrue(packed.startFocus(.twentyFive, track: .nightInsects))
        packed.tickFocus(1500)
        let packedReward = packed.finishFocus()
        XCTAssertEqual(packedReward?.fireflyDust, 10)
        XCTAssertEqual(packed.state.fireflyDust, 10)
    }
}
