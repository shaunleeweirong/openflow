import XCTest
@testable import OpenFlow

final class AchievementEngineTests: XCTestCase {
    private func progress(words: Int = 0, dictations: Int = 0, streak: Int = 0) -> ProgressSnapshot {
        ProgressSnapshot(totalWords: words, totalDictations: dictations, currentDailyStreak: streak)
    }

    func testFirstDictationFiresOnZeroToOne() {
        let out = AchievementEngine.newlyUnlocked(
            old: progress(words: 0, dictations: 0),
            new: progress(words: 10, dictations: 1),
            alreadyUnlocked: []
        )
        XCTAssertTrue(out.contains { $0.id == "first_dictation" })
    }

    func testFirstDictationNeverFiresAgain() {
        let out = AchievementEngine.newlyUnlocked(
            old: progress(words: 10, dictations: 1),
            new: progress(words: 20, dictations: 2),
            alreadyUnlocked: ["first_dictation"]
        )
        XCTAssertFalse(out.contains { $0.id == "first_dictation" })
    }

    func testSingleWordTierCrossing() {
        let out = AchievementEngine.newlyUnlocked(
            old: progress(words: 900, dictations: 5),
            new: progress(words: 1_100, dictations: 6),
            alreadyUnlocked: ["first_dictation"]
        )
        XCTAssertEqual(out.map(\.id), ["words_1000"])
    }

    func testHugeDictationCrossesManyTiersCelebratesHighest() {
        let out = AchievementEngine.newlyUnlocked(
            old: progress(words: 0, dictations: 0),
            new: progress(words: 60_000, dictations: 1),
            alreadyUnlocked: []
        )
        // All crossed tiers returned (through 50k, not 100k), plus first_dictation.
        XCTAssertTrue(out.contains { $0.id == "words_50000" })
        XCTAssertFalse(out.contains { $0.id == "words_100000" })
        XCTAssertTrue(out.contains { $0.id == "first_dictation" })
        // Only the highest is celebrated.
        XCTAssertEqual(AchievementEngine.highest(out)?.id, "words_50000")
    }

    func testAlreadyUnlockedNeverReturned() {
        let out = AchievementEngine.newlyUnlocked(
            old: progress(words: 900, dictations: 5),
            new: progress(words: 1_100, dictations: 6),
            alreadyUnlocked: ["first_dictation", "words_1000"]
        )
        XCTAssertFalse(out.contains { $0.id == "words_1000" })
    }

    func testStreakFiresAtExactThreshold() {
        let crossing = AchievementEngine.newlyUnlocked(
            old: progress(dictations: 5, streak: 6),
            new: progress(dictations: 5, streak: 7),
            alreadyUnlocked: ["streak_3"]
        )
        XCTAssertTrue(crossing.contains { $0.id == "streak_7" })

        let notYet = AchievementEngine.newlyUnlocked(
            old: progress(dictations: 5, streak: 5),
            new: progress(dictations: 5, streak: 6),
            alreadyUnlocked: ["streak_3"]
        )
        XCTAssertFalse(notYet.contains { $0.id == "streak_7" })
    }

    func testNoCrossingReturnsEmpty() {
        let allIDs = Set(AchievementCatalog.all.map(\.id))
        let out = AchievementEngine.newlyUnlocked(
            old: progress(words: 100, dictations: 2, streak: 1),
            new: progress(words: 100, dictations: 2, streak: 1),
            alreadyUnlocked: allIDs
        )
        XCTAssertTrue(out.isEmpty)
    }
}
