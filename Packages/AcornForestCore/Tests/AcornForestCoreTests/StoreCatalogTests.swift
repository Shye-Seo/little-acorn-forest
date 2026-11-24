import XCTest
import AcornForestCore

final class StoreCatalogTests: XCTestCase {
    func testThreeProductsWithExactPrices() {
        XCTAssertEqual(StoreCatalog.all.count, 3)
        XCTAssertEqual(ContentPack.greenhouse.priceKRW, 4400)
        XCTAssertEqual(ContentPack.bottleWorkshop.priceKRW, 2500)
        XCTAssertEqual(ContentPack.asmrTracks.priceKRW, 1900)
        XCTAssertEqual(StoreCatalog.totalPriceKRW, 8800)
        XCTAssertEqual(StoreCatalog.productIDs.count, 3)
        XCTAssertEqual(Set(StoreCatalog.productIDs).count, 3)
    }

    func testProductIdentifiersAreStable() {
        XCTAssertEqual(ContentPack.greenhouse.productID, "com.quoguri.moonlightjamjar.greenhouse")
        XCTAssertEqual(ContentPack.bottleWorkshop.productID, "com.quoguri.moonlightjamjar.bottleskins")
        XCTAssertEqual(ContentPack.asmrTracks.productID, "com.quoguri.moonlightjamjar.asmrpack")
        for pack in ContentPack.allCases {
            XCTAssertTrue(pack.productID.hasPrefix("com.quoguri.moonlightjamjar."))
            XCTAssertEqual(StoreCatalog.pack(forProductID: pack.productID), pack)
        }
        XCTAssertNil(StoreCatalog.pack(forProductID: "com.example.nope"))
        XCTAssertFalse(StoreCatalog.isKnownProductID("nope"))
    }

    func testPriceLineUsesWonMark() {
        for pack in ContentPack.allCases {
            XCTAssertTrue(pack.priceLine.hasPrefix("₩"), pack.priceLine)
        }
        XCTAssertTrue(ContentPack.greenhouse.priceLine.contains("4400") || ContentPack.greenhouse.priceLine.contains("4,400"))
    }

    func testGrantingIsIdempotentAndSaved() throws {
        let engine = TestSupport.engine()
        XCTAssertFalse(engine.owns(.greenhouse))
        XCTAssertTrue(engine.grantPack(.greenhouse))
        XCTAssertFalse(engine.grantPack(.greenhouse))
        XCTAssertTrue(engine.owns(.greenhouse))
        XCTAssertTrue(engine.state.hasFlag("store.owned.greenhouse"))
        let data = try SaveCodec.encode(SaveFile(state: engine.state))
        let restored = try SaveCodec.decode(data)
        XCTAssertTrue(restored.state.owns(.greenhouse))
    }

    func testGreenhousePackOpensPlaceRecipesAndNeighbours() {
        let state = TestSupport.stockedState([])
        let before = TestSupport.engine(state: state)
        XCTAssertEqual(before.visibleCharacters.count, 4)
        XCTAssertFalse(before.isLocationUnlocked(.greenhouse))
        XCTAssertTrue(before.lockMessage(for: .greenhouse).contains("사계절 온실"))

        let engine = TestSupport.engine(state: state)
        engine.grantPack(.greenhouse)
        XCTAssertEqual(engine.visibleCharacters.count, 6)
        XCTAssertTrue(engine.visibleCharacters.contains(.luna))
        XCTAssertTrue(engine.visibleCharacters.contains(.coco))
        XCTAssertTrue(engine.visibleIngredients.contains(.cherryHoney))
    }

    func testGreenhouseUnlocksAfterEpilogueOnly() {
        var state = TestSupport.stockedState([])
        state.grant(.greenhouse)
        let early = TestSupport.engine(state: state)
        XCTAssertFalse(early.isLocationUnlocked(.greenhouse))

        state.markCompleted(.prologue)
        state.markCompleted(.chapterOne)
        state.markCompleted(.chapterTwo)
        state.markCompleted(.chapterThree)
        state.markCompleted(.epilogue)
        let finished = TestSupport.engine(state: state)
        XCTAssertTrue(finished.isLocationUnlocked(.greenhouse))
    }

    func testWorkshopPackReflectsEverywhere() {
        let engine = TestSupport.engine()
        XCTAssertEqual(engine.state.unlockedBottles.count, 3)
        XCTAssertEqual(engine.state.unlockedCabinStyles.count, 1)
        engine.grantPack(.bottleWorkshop)
        XCTAssertEqual(engine.state.unlockedBottles.count, 4)
        XCTAssertEqual(engine.state.unlockedCabinStyles.count, 3)
        engine.setCabinStyle(.starWall)
        XCTAssertEqual(engine.state.cabinStyle, .starWall)
        engine.revokePack(.bottleWorkshop)
        XCTAssertEqual(engine.state.cabinStyle, .attic, "스킨을 잃으면 기본 오두막으로 돌아간다")
    }

    func testASMRPackAddsTracksAndKeepsFreeGameIntact() {
        let engine = TestSupport.engine()
        XCTAssertEqual(engine.state.unlockedTracks.count, 3)
        engine.grantPack(.asmrTracks)
        XCTAssertEqual(engine.state.unlockedTracks.count, 5)
        XCTAssertTrue(engine.isTrackAvailable(.windChime))
        XCTAssertFalse(engine.owns(.greenhouse))
    }

    func testCardContentsDescribeRealUnlocks() {
        for pack in ContentPack.allCases {
            XCTAssertFalse(pack.displayName.isEmpty)
            XCTAssertFalse(pack.tagline.isEmpty)
            XCTAssertGreaterThanOrEqual(pack.contents.count, 3, "\(pack.displayName) 내용 목록")
            XCTAssertFalse(pack.emoji.isEmpty)
        }
    }
}
