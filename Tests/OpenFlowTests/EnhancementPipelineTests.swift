import XCTest
@testable import OpenFlow

/// Configurable fake so the pipeline's fallback matrix can be tested without any model.
private final class MockEnhancer: Enhancer {
    enum Behavior {
        case succeed(String)
        case fail
        case delay(Duration, then: String)
    }

    struct EnhanceError: Error {}

    var isAvailable: Bool
    private let behavior: Behavior

    init(isAvailable: Bool = true, _ behavior: Behavior) {
        self.isAvailable = isAvailable
        self.behavior = behavior
    }

    func enhance(_ text: String, vocabulary: [DictionaryEntry]) async throws -> String {
        switch behavior {
        case .succeed(let s): return s
        case .fail: throw EnhanceError()
        case .delay(let d, let s):
            try await Task.sleep(for: d)
            return s
        }
    }
}

final class EnhancementPipelineTests: XCTestCase {
    private func pipeline(
        enhancer: Enhancer?,
        aiEnhanceEnabled: Bool = true,
        removeFillers: Bool = true,
        dictionary: [DictionaryEntry] = [],
        timeout: Duration = .seconds(4)
    ) -> EnhancementPipeline {
        EnhancementPipeline(
            enhancer: enhancer,
            aiEnhanceEnabled: aiEnhanceEnabled,
            removeFillers: removeFillers,
            dictionary: dictionary,
            timeout: timeout
        )
    }

    // MARK: - Deterministic paths (no LLM used)

    func testAiDisabledUsesDeterministicCleanup() async {
        let p = pipeline(enhancer: MockEnhancer(.succeed("SHOULD NOT BE USED")),
                         aiEnhanceEnabled: false)
        let result = await p.run("um hello the the world")
        XCTAssertEqual(result, "Hello the world")
    }

    func testUnavailableEnhancerUsesDeterministicCleanup() async {
        let p = pipeline(enhancer: MockEnhancer(isAvailable: false, .succeed("SHOULD NOT BE USED")))
        let result = await p.run("um hello the the world")
        XCTAssertEqual(result, "Hello the world")
    }

    // MARK: - Enhanced path used on success

    func testSuccessfulEnhancementIsUsed() async {
        let p = pipeline(enhancer: MockEnhancer(.succeed("Hello, world.")))
        let result = await p.run("um hello world")
        // The LLM's cleaner output is used verbatim, not the deterministic "Hello world".
        XCTAssertEqual(result, "Hello, world.")
    }

    func testDictionaryAppliedToEnhancedOutput() async {
        let dict = [DictionaryEntry(spoken: "super base", written: "Supabase")]
        let p = pipeline(enhancer: MockEnhancer(.succeed("deploy to super base")),
                         dictionary: dict)
        let result = await p.run("umm deploy to super base now")
        // Custom spelling is guaranteed on the LLM output; we don't re-tidy its casing.
        XCTAssertEqual(result, "deploy to Supabase")
    }

    // MARK: - Fallback to deterministic on bad output

    func testThrowingEnhancerFallsBackToDeterministic() async {
        let p = pipeline(enhancer: MockEnhancer(.fail))
        let result = await p.run("um hello world")
        XCTAssertEqual(result, "Hello world")
    }

    func testEmptyEnhancementFallsBackToDeterministic() async {
        let p = pipeline(enhancer: MockEnhancer(.succeed("   ")))
        let result = await p.run("um hello world")
        XCTAssertEqual(result, "Hello world")
    }

    func testOverlongEnhancementFallsBackToDeterministic() async {
        let bloated = "This whole thing was rewritten and expanded far beyond the original utterance."
        let p = pipeline(enhancer: MockEnhancer(.succeed(bloated)))
        let result = await p.run("hi there")
        XCTAssertEqual(result, "Hi there")
    }

    func testTimeoutFallsBackToDeterministic() async {
        let p = pipeline(enhancer: MockEnhancer(.delay(.seconds(2), then: "late enhanced text")),
                         timeout: .milliseconds(50))
        let result = await p.run("um hello world")
        XCTAssertEqual(result, "Hello world")
    }
}
