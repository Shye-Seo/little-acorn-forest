import XCTest
import AcornForestCore

final class JarShelfTests: XCTestCase {
    private func engineWithJam(servings: Int = 1, packs: [ContentPack] = []) -> GameEngine {
        var state = TestSupport.stockedState([])
        state.addCooked(recipeID: "dawn-dew-jam", quality: .perfect, extraServings: max(0, servings - 1))
        for pack in packs {
            state.grant(pack)
        }
        return TestSupport.engine(state: state)
    }

    func testStyleCatalogHidesWorkshopStylesUntilBought() {
        XCTAssertEqual(JarStyleCatalog.bottles(ownsWorkshop: false).count, 3)
        XCTAssertEqual(JarStyleCatalog.bottles(ownsWorkshop: true).count, 4)
        XCTAssertEqual(JarStyleCatalog.caps(ownsWorkshop: false).count, 3)
        XCTAssertEqual(JarStyleCatalog.caps(ownsWorkshop: true).count, 4)
        XCTAssertFalse(JarStyleCatalog.isUnlocked(.crystal, ownsWorkshop: false))
        XCTAssertTrue(JarStyleCatalog.isUnlocked(.starCap, ownsWorkshop: true))
        XCTAssertEqual(JarShelf.capacity, 9)
    }

    func testLabelIsTrimmedAndShortened() {
        XCTAssertEqual(JarShelf.sanitizedLabel("  새벽   이슬  "), "새벽 이슬")
        XCTAssertEqual(JarShelf.sanitizedLabel("줄\n바꿈"), "줄 바꿈")
        let long = String(repeating: "가", count: 40)
        XCTAssertEqual(JarShelf.sanitizedLabel(long).count, JarShelf.labelLimit)
        XCTAssertEqual(JarShelf.defaultLabel(for: "dawn-dew-jam"), "새벽이슬 잼")
    }

    func testDecorateConsumesServingAndPlacesJar() {
        let engine = engineWithJam(servings: 2)
        let outcome = engine.decorateJar(recipeID: "dawn-dew-jam",
                                         bottle: .roundGlass,
                                         cap: .cork,
                                         ribbon: .sage,
                                         label: " 첫 병 ")
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(engine.state.servings(of: "dawn-dew-jam"), 1)
        XCTAssertEqual(engine.shelfJars.count, 1)
        XCTAssertEqual(engine.shelfJars[0].slot, 0)
        XCTAssertEqual(engine.shelfJars[0].label, "첫 병")
        XCTAssertEqual(engine.shelfJars[0].displayLabel, "첫 병")
    }

    func testDecorateWithoutJamFails() {
        let engine = TestSupport.engine(state: TestSupport.stockedState([]))
        let outcome = engine.decorateJar(recipeID: "dawn-dew-jam",
                                         bottle: .roundGlass,
                                         cap: .cork,
                                         ribbon: .sage,
                                         label: "")
        XCTAssertFalse(outcome.succeeded)
        XCTAssertTrue(engine.shelfJars.isEmpty)
    }

    func testWorkshopStylesNeedThePack() {
        let engine = engineWithJam(servings: 2)
        let locked = engine.decorateJar(recipeID: "dawn-dew-jam",
                                        bottle: .crystal,
                                        cap: .cork,
                                        ribbon: .sage,
                                        label: "")
        XCTAssertFalse(locked.succeeded)
        XCTAssertTrue(locked.message.contains("병 공방"))

        engine.grantPack(.bottleWorkshop)
        let opened = engine.decorateJar(recipeID: "dawn-dew-jam",
                                        bottle: .crystal,
                                        cap: .starCap,
                                        ribbon: .moonflake,
                                        label: "크리스탈")
        XCTAssertTrue(opened.succeeded)
        XCTAssertEqual(engine.shelfJars.first?.bottle, .crystal)
        XCTAssertEqual(engine.shelfJars.first?.cap, .starCap)
    }

    func testShelfFillsAndRefusesTenthJar() {
        let engine = engineWithJam(servings: 10)
        for index in 0..<JarShelf.capacity {
            let outcome = engine.decorateJar(recipeID: "dawn-dew-jam",
                                             bottle: .roundGlass,
                                             cap: .cork,
                                             ribbon: .sage,
                                             label: "\(index)")
            XCTAssertTrue(outcome.succeeded, "\(index)번째 병")
        }
        XCTAssertEqual(engine.shelfJars.count, JarShelf.capacity)
        let overflow = engine.decorateJar(recipeID: "dawn-dew-jam",
                                          bottle: .roundGlass,
                                          cap: .cork,
                                          ribbon: .sage,
                                          label: "넘침")
        XCTAssertFalse(overflow.succeeded)
        XCTAssertTrue(overflow.message.contains("가득"))
        XCTAssertEqual(engine.state.servings(of: "dawn-dew-jam"), 1, "실패한 꾸미기는 잼을 쓰지 않는다")
    }

    func testRemovingJarCompactsSlots() {
        let engine = engineWithJam(servings: 3)
        for label in ["하나", "둘", "셋"] {
            _ = engine.decorateJar(recipeID: "dawn-dew-jam",
                                   bottle: .gourd,
                                   cap: .checkCloth,
                                   ribbon: .berry,
                                   label: label)
        }
        let middle = engine.shelfJars[1]
        XCTAssertTrue(engine.removeJar(id: middle.id))
        XCTAssertEqual(engine.shelfJars.map(\.slot), [0, 1])
        XCTAssertEqual(engine.shelfJars.map(\.label), ["하나", "셋"])
    }

    func testJarLabelFallsBackToRecipeNameAndDetail() {
        let jar = CustomJamJar(recipeID: "starlight-mist-jam", bottle: .starVial, cap: .moonlightMetal, ribbon: .dew)
        XCTAssertEqual(jar.displayLabel, "별빛 안개 잼")
        XCTAssertTrue(jar.detailLine.contains("별빛 각병"))
        XCTAssertTrue(jar.detailLine.contains("달빛 금속"))
        XCTAssertTrue(jar.moonLine.contains("담근 병"))
    }

    func testShelfRulesNormalizeDuplicateSlots() {
        var state = TestSupport.stockedState([])
        state.jars = [
            CustomJamJar(recipeID: "dawn-dew-jam", slot: 3),
            CustomJamJar(recipeID: "dawn-dew-jam", slot: 3),
            CustomJamJar(recipeID: "dawn-dew-jam", slot: 99)
        ]
        state.normalize()
        XCTAssertEqual(Set(state.jars.map(\.slot)), [0, 1, 3])
        XCTAssertEqual(state.jars.count, 3)
        XCTAssertEqual(state.shelfJars.map(\.slot), [0, 1, 3])
    }

    func testCabinStylesFollowTheWorkshopPack() {
        XCTAssertEqual(CabinStyle.styles(ownsWorkshop: false).count, 1)
        XCTAssertEqual(CabinStyle.styles(ownsWorkshop: true).count, 3)
        XCTAssertEqual(CabinStyle.attic.requiredPack, nil)
        XCTAssertEqual(CabinStyle.starWall.requiredPack, .bottleWorkshop)
        XCTAssertNotEqual(CabinStyle.starWall.wallHex, CabinStyle.attic.wallHex)
    }
}
