import XCTest
import AcornForestCore

final class RecipeTests: XCTestCase {
    func testRecipeLookupIgnoresOrder() {
        XCTAssertEqual(RecipeBook.recipe(for: [.dewberry, .fireflyNectar])?.id, "firefly-sparkle-jam")
        XCTAssertEqual(RecipeBook.recipe(for: [.fireflyNectar, .dewberry])?.id, "firefly-sparkle-jam")
        XCTAssertEqual(RecipeBook.recipe(for: [.moonflakeSpice, .dewberry, .starMossShroom])?.id, "meteor-berry-compote")
    }

    func testEveryRecipeUsesTwoOrThreeIngredients() {
        XCTAssertGreaterThanOrEqual(RecipeBook.all.count, 6)
        for recipe in RecipeBook.all {
            XCTAssertTrue((2...3).contains(recipe.ingredients.count), "\(recipe.name) 재료 수")
            if !recipe.hasDistinctIngredients {
                XCTAssertEqual(recipe.id, "dawn-dew-jam", "같은 재료를 두 번 쓰는 잼은 새벽이슬 잼뿐이어야 한다")
                XCTAssertEqual(recipe.ingredients.count, 2)
            }
            XCTAssertFalse(recipe.story.isEmpty)
        }
    }

    func testCombinationKeysAreUnique() {
        let keys = RecipeBook.all.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "같은 조합의 레시피가 두 개 이상 있다")
    }

    func testUnknownCombinationReturnsNil() {
        XCTAssertNil(RecipeBook.recipe(for: [.fireflyNectar, .fireflyNectar]))
        XCTAssertNil(RecipeBook.recipe(for: []))
        XCTAssertNil(RecipeBook.recipe(for: [.dewberry]))
    }

    func testDoubledBerryIsItsOwnRecipe() {
        XCTAssertEqual(RecipeBook.recipe(for: [.dewberry, .dewberry])?.id, "dawn-dew-jam")
        XCTAssertEqual(RecipeBook.key(for: [.dewberry, .dewberry]), "dewberry+dewberry")
        XCTAssertNotEqual(RecipeBook.recipe(for: [.dewberry, .dewberry])?.id,
                          RecipeBook.recipe(for: [.dewberry, .fireflyNectar])?.id)
    }

    func testClosestRecipeSuggestsOverlap() {
        guard let hint = RecipeBook.closestRecipe(to: [.dewberry, .moonflakeSpice]) else {
            return XCTFail("가까운 레시피를 찾지 못했다")
        }
        XCTAssertTrue(hint.ingredients.contains(.dewberry) || hint.ingredients.contains(.moonflakeSpice))
        XCTAssertNil(RecipeBook.closestRecipe(to: []))
    }

    func testSignatureFestivalJamExists() {
        let jam = RecipeBook.recipe(id: "golden-fullmoon-jam")
        XCTAssertNotNil(jam)
        XCTAssertEqual(jam?.key, "fireflyNectar+moonflakeSpice+starMossShroom")
        XCTAssertEqual(jam?.warmth, 3)
        XCTAssertEqual(jam?.minChapter, .chapterThree)
    }

    func testUnCookedRecipesShrinkAfterCooking() {
        var state = GameEngine.freshState()
        let before = RecipeBook.unCooked(in: state).count
        state.addCooked(recipeID: "dawn-dew-jam", quality: .good)
        XCTAssertEqual(RecipeBook.unCooked(in: state).count, before - 1)
    }
}
