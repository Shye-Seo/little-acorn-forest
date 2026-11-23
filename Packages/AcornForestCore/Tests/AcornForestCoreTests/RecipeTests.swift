import XCTest
import AcornForestCore

final class RecipeTests: XCTestCase {
    func testRecipeLookupIgnoresOrder() {
        XCTAssertEqual(RecipeBook.recipe(for: [.raspberry, .acorn])?.id, "acorn-pie")
        XCTAssertEqual(RecipeBook.recipe(for: [.acorn, .raspberry])?.id, "acorn-pie")
        XCTAssertEqual(RecipeBook.recipe(for: [.moonHerb, .honeyMushroom, .acorn])?.id, "grandma-porridge")
    }

    func testEveryRecipeUsesTwoOrThreeDistinctIngredients() {
        XCTAssertGreaterThanOrEqual(RecipeBook.all.count, 6)
        for recipe in RecipeBook.all {
            XCTAssertTrue((2...3).contains(recipe.ingredients.count), "\(recipe.name) 재료 수")
            XCTAssertTrue(recipe.hasDistinctIngredients, "\(recipe.name) 중복 재료")
            XCTAssertFalse(recipe.story.isEmpty)
        }
    }

    func testCombinationKeysAreUnique() {
        let keys = RecipeBook.all.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "같은 조합의 레시피가 두 개 이상 있다")
    }

    func testUnknownCombinationReturnsNil() {
        XCTAssertNil(RecipeBook.recipe(for: [.acorn, .acorn]))
        XCTAssertNil(RecipeBook.recipe(for: []))
        XCTAssertNil(RecipeBook.recipe(for: [.raspberry]))
    }

    func testDuplicateIngredientsAreNotSilentlyDeduped() {
        XCTAssertNil(RecipeBook.recipe(for: [.raspberry, .raspberry]))
        XCTAssertEqual(RecipeBook.key(for: [.raspberry, .raspberry]), "raspberry+raspberry")
    }

    func testClosestRecipeSuggestsOverlap() {
        guard let hint = RecipeBook.closestRecipe(to: [.acorn, .moonHerb]) else {
            return XCTFail("가까운 레시피를 찾지 못했다")
        }
        XCTAssertTrue(hint.ingredients.contains(.acorn) || hint.ingredients.contains(.moonHerb))
        XCTAssertNil(RecipeBook.closestRecipe(to: []))
    }

    func testSpecialCakeExistsForFestival() {
        let cake = RecipeBook.recipe(id: "starlight-cake")
        XCTAssertNotNil(cake)
        XCTAssertEqual(cake?.key, "acorn+moonHerb+raspberry")
        XCTAssertEqual(cake?.warmth, 3)
    }

    func testUnCookedRecipesShrinkAfterCooking() {
        var state = GameEngine.freshState()
        let before = RecipeBook.unCooked(in: state).count
        state.addCooked(recipeID: "acorn-pie", quality: .good)
        XCTAssertEqual(RecipeBook.unCooked(in: state).count, before - 1)
    }
}
