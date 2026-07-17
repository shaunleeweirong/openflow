import Foundation

/// One completed dictation, normalized for the stats layer. Built at the recording point
/// in `AppDelegate.finishDictation()` and handed to `StatsStore.record(_:)`.
struct DictationEvent: Equatable {
    var date: Date
    var wordCount: Int
    var spokenSeconds: Double
    var appBundleID: String?
    var appName: String?

    init(
        date: Date,
        wordCount: Int,
        spokenSeconds: Double,
        appBundleID: String? = nil,
        appName: String? = nil
    ) {
        self.date = date
        self.wordCount = wordCount
        self.spokenSeconds = spokenSeconds
        self.appBundleID = appBundleID
        self.appName = appName
    }
}

/// The single definition of "a word", shared by the recording path and the tests.
enum WordCounter {
    /// Counts whitespace-separated tokens. `split` omits empty subsequences, so runs of
    /// spaces/newlines/tabs and leading/trailing whitespace never inflate the count.
    static func count(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }
}
