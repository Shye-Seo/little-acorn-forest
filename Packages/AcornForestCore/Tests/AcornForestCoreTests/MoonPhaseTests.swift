import XCTest
import AcornForestCore

final class MoonPhaseTests: XCTestCase {
    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: iso) ?? Date()
    }

    func testPhaseFractionStaysInsideOneCycle() {
        let samples = [
            MoonCalendar.referenceNewMoon,
            MoonCalendar.referenceNewMoon.addingTimeInterval(86_400 * 5),
            MoonCalendar.referenceNewMoon.addingTimeInterval(-86_400 * 400),
            MoonCalendar.referenceNewMoon.addingTimeInterval(86_400 * 12_000)
        ]
        for sample in samples {
            let fraction = MoonCalendar.phaseFraction(at: sample)
            XCTAssertGreaterThanOrEqual(fraction, 0)
            XCTAssertLessThan(fraction, 1)
        }
    }

    func testOneSynodicMonthReturnsToSameFraction() {
        let start = date("2026-05-01T00:00:00Z")
        let next = start.addingTimeInterval(MoonCalendar.synodicMonth * 86_400)
        XCTAssertEqual(MoonCalendar.phaseFraction(at: start),
                       MoonCalendar.phaseFraction(at: next),
                       accuracy: 0.0001)
    }

    func testKnownFullMoonsAreFullMoonNights() {
        // 2026-03-03과 2026-08-28은 실제 개기월식이 있었던 보름이다.
        XCTAssertEqual(MoonCalendar.phase(at: date("2026-03-03T12:00:00Z")), .fullMoon)
        XCTAssertEqual(MoonCalendar.phase(at: date("2026-08-28T12:00:00Z")), .fullMoon)
        XCTAssertEqual(MoonCalendar.phase(at: date("2025-03-14T12:00:00Z")), .fullMoon)
    }

    func testCrescentFollowsTheNewMoon() {
        // 2024-04-08 개기일식(삭) 다음 날은 초승달이다.
        XCTAssertEqual(MoonCalendar.phase(at: date("2024-04-09T12:00:00Z")), .crescent)
    }

    func testFirstQuarterWindow() {
        let quarter = MoonCalendar.referenceNewMoon
            .addingTimeInterval(MoonCalendar.synodicMonth * 0.25 * 86_400)
        XCTAssertEqual(MoonCalendar.phase(at: quarter), .firstQuarter)
    }

    func testIlluminationPeaksAtFullMoon() {
        let full = date("2026-08-28T12:00:00Z")
        XCTAssertGreaterThan(MoonCalendar.illumination(at: full), 0.99)
        let new = MoonCalendar.referenceNewMoon
        XCTAssertLessThan(MoonCalendar.illumination(at: new), 0.01)
    }

    func testDaysUntilFullMoonIsShortOnFullMoonNight() {
        let full = date("2026-08-28T12:00:00Z")
        XCTAssertLessThan(MoonCalendar.daysUntilFullMoon(at: full), 1.5)
        let new = MoonCalendar.referenceNewMoon
        XCTAssertEqual(MoonCalendar.daysUntilFullMoon(at: new),
                       MoonCalendar.synodicMonth / 2,
                       accuracy: 0.2)
    }

    func testMoonClockOverrideWins() {
        let clock = MoonClock(overridePhase: .firstQuarter)
        XCTAssertEqual(clock.phase(at: Date()), .firstQuarter)
        XCTAssertTrue(clock.isOverridden)
        XCTAssertEqual(MoonClock().phase(at: date("2026-03-03T12:00:00Z")), .fullMoon)
        XCTAssertFalse(MoonClock().isOverridden)
    }

    func testPhaseTitlesAreDistinct() {
        let titles = MoonPhase.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, 4)
        XCTAssertTrue(titles.contains("초승달"))
        XCTAssertTrue(titles.contains("상현달"))
        XCTAssertTrue(titles.contains("보름달"))
        XCTAssertTrue(titles.contains("그믐달"))
        XCTAssertTrue(MoonPhase.fullMoon.isFullMoon)
        XCTAssertFalse(MoonPhase.waning.isFullMoon)
        XCTAssertTrue(MoonPhase.fullMoon.opensSecretGarden)
    }

    func testMoonGardenOnlyOpensOnFullMoon() {
        XCTAssertTrue(MoonGarden.isOpen(phase: .fullMoon))
        XCTAssertFalse(MoonGarden.isOpen(phase: .crescent))
        XCTAssertFalse(MoonGarden.isOpen(phase: .firstQuarter))
        XCTAssertFalse(MoonGarden.isOpen(phase: .waning))
        XCTAssertTrue(MoonGarden.closedMessage(daysUntilFullMoon: 3).contains("3일"))
        XCTAssertTrue(MoonGarden.statusLine(phase: .fullMoon, daysUntilFullMoon: 0).contains("열렸"))
    }

    func testSecretGardenIsLockedOnOtherNights() {
        var state = TestSupport.stateWithPrologueDone()
        state.markCompleted(.chapterOne)
        let engine = TestSupport.engine(state: state, moon: .waning)
        XCTAssertFalse(engine.isMoonlitGardenOpen)
        XCTAssertFalse(engine.startGathering(at: .moonlitGarden, seed: 3))
        XCTAssertTrue(engine.lastMessage.contains("보름달"))
        XCTAssertFalse(engine.isLocationUnlocked(.moonlitGarden))
    }

    func testSecretGardenYieldsMoonlitDewOnFullMoon() {
        var state = TestSupport.stateWithPrologueDone()
        state.markCompleted(.chapterOne)
        let engine = TestSupport.engine(state: state, moon: .fullMoon)
        XCTAssertTrue(engine.isMoonlitGardenOpen)
        XCTAssertTrue(engine.isLocationUnlocked(.moonlitGarden))
        XCTAssertTrue(engine.startGathering(at: .moonlitGarden, seed: 21))
        TestSupport.catchEverything(engine)
        XCTAssertGreaterThan(engine.state.count(of: .moonlitDew), 0, "보름달 정원에서는 월광 이슬이 나온다")
        XCTAssertTrue(engine.moonBadgeLine.contains("보름달"))
    }

    func testMoonBadgeShowsDaysUntilNextFullMoon() {
        let engine = TestSupport.engine(moon: .crescent)
        XCTAssertTrue(engine.moonBadgeLine.contains("초승달"))
        XCTAssertTrue(engine.moonBadgeLine.contains("다음 보름달까지"))
    }

    func testDebugOverrideIsSaved() {
        let engine = TestSupport.engine()
        engine.setMoonOverride(.fullMoon)
        XCTAssertEqual(engine.currentMoonPhase, .fullMoon)
        XCTAssertTrue(engine.state.debugMoonOverride == .fullMoon)
        engine.setMoonOverride(nil)
        XCTAssertNil(engine.state.debugMoonOverride)
    }
}
