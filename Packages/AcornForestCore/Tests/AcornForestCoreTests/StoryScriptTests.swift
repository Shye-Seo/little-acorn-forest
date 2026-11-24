import XCTest
import AcornForestCore

final class StoryScriptTests: XCTestCase {
    func testEveryChapterHasAtLeastOneScene() {
        for chapter in StoryChapter.allCases {
            XCTAssertFalse(StoryScript.scenes(in: chapter).isEmpty, "\(chapter.title)에 장면이 없다")
        }
        XCTAssertGreaterThanOrEqual(StoryScript.sceneCount, 8)
    }

    func testSceneIdentifiersAreUnique() {
        let ids = StoryScript.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testLineIdentifiersAreUniqueAcrossTheScript() {
        let ids = StoryScript.all.flatMap { $0.lines.map(\.id) }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEverySceneHasLinesAndAThought() {
        for scene in StoryScript.all {
            XCTAssertGreaterThanOrEqual(scene.lines.count, 4, "\(scene.title) 대사가 너무 적다")
            XCTAssertFalse(scene.closingThought.isEmpty)
            XCTAssertFalse(scene.title.isEmpty)
        }
    }

    func testChoicesAreWellFormed() {
        var choiceIDs: [String] = []
        for scene in StoryScript.all {
            for choice in scene.choices {
                choiceIDs.append(choice.id)
                XCTAssertFalse(choice.text.isEmpty)
                XCTAssertTrue(choice.gains.count >= 1 || choice.flag != nil, "\(choice.id)에 효과가 없다")
                if let reply = choice.reply {
                    XCTAssertFalse(reply.text.isEmpty)
                }
            }
            XCTAssertLessThanOrEqual(scene.choices.count, 4)
        }
        XCTAssertEqual(Set(choiceIDs).count, choiceIDs.count)
    }

    func testStoryGrantsOnlyRealIngredients() {
        for scene in StoryScript.all {
            for stack in scene.grants {
                XCTAssertTrue(Ingredient.allCases.contains(stack.ingredient))
                XCTAssertGreaterThan(stack.count, 0)
            }
        }
    }

    func testDiaryUnlocksPointAtRealEntries() {
        for scene in StoryScript.all {
            for id in scene.unlocksDiary {
                XCTAssertNotNil(ForestDiary.entry(id: id), "\(id)가 일기장 목차에 없다")
            }
        }
    }

    func testFourNeighboursSpeakInTheStory() {
        let speakers = Set(StoryScript.all.flatMap { $0.lines.map(\.speaker) })
        for character in CharacterID.coreNeighbours {
            let speaker = StorySpeaker(rawValue: character.rawValue)
            XCTAssertNotNil(speaker)
            XCTAssertTrue(speakers.contains(speaker ?? .narrator), "\(character.name)의 대사가 없다")
        }
        XCTAssertTrue(speakers.contains(.bori))
        XCTAssertTrue(speakers.contains(.narrator))
    }

    func testChapterSceneLookup() {
        XCTAssertNotNil(StoryScript.scene(chapter: .prologue, index: 0))
        XCTAssertNotNil(StoryScript.scene(id: "prologue.key"))
        XCTAssertNil(StoryScript.scene(chapter: .prologue, index: 99))
        XCTAssertEqual(StoryScript.scenes(in: .prologue).count, 2)
    }

    func testEpilogueUnlocksFestivalEntry() {
        let epilogue = StoryScript.scenes(in: .epilogue)
        XCTAssertEqual(epilogue.count, 1)
        XCTAssertTrue(epilogue[0].unlocksDiary.contains(ForestDiary.festivalEntryID))
    }

    func testChoiceFlagsAreUnique() {
        let flags = StoryScript.all.flatMap { $0.choices.compactMap(\.flag) }
        XCTAssertEqual(Set(flags).count, flags.count, "같은 깃발을 쓰는 선택지가 있다")
    }
}
