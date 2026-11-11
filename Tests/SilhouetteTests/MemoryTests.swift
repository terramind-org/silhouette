import CoreText
import XCTest
@testable import Silhouette

private struct Account: Codable, Equatable {
    var name: String
    var balance: Double
    var followers: Int
    var verified: Bool
    var tags: [String]
}

private enum Tier: String, Codable { case free, pro }
private struct Plan: Codable { var tier: Tier }

@MainActor
final class MemoryTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "silhouette.tests.\(UUID().uuidString)")
        SkeletonMemory.defaults = defaults
    }

    override func tearDown() async throws {
        SkeletonMemory.defaults = .standard
    }

    func testScrubbingKeepsLengthsAndDropsContent() throws {
        let real = Account(name: "Ada Lovelace", balance: 48210.55, followers: 2314, verified: true, tags: ["math", "Engines"])
        let data = try ShapeScrubber.scrub(real)
        let shape = try JSONDecoder().decode(Account.self, from: data)
        XCTAssertEqual(shape.name, "Nna Enaalaaa")
        XCTAssertEqual(shape.name.count, real.name.count)
        XCTAssertEqual(shape.tags, ["matn", "Ennlnaa"])
        XCTAssertEqual(String(Int(shape.balance)).count, String(Int(real.balance)).count)
        XCTAssertNotEqual(shape.balance, real.balance)
        XCTAssertEqual(shape.followers, 8888)
        XCTAssertTrue(shape.verified)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Ada"))
    }

    func testRememberedTextKeepsItsWidthSoItWrapsTheSame() {
        let real = "Writes programs for an engine nobody has built yet. Her notes run longer than the paper."
        let shape = ShapeScrubber.scrub(string: real)
        func width(_ s: String) -> Double {
            let font = CTFontCreateUIFontForLanguage(.system, 15, nil)!
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
            return CTLineGetTypographicBounds(line, nil, nil, nil)
        }
        XCTAssertEqual(width(shape) / width(real), 1, accuracy: 0.03, "\(shape)")
        XCTAssertFalse(shape.contains("programs"))
    }

    func testCodableShapesAreRememberedAcrossLaunchesAndForgotten() {
        let codec = ShapeCodec<Account>.codable
        codec.save(Account(name: "Grace Hopper", balance: 12, followers: 3, verified: false, tags: []), "inbox")
        XCTAssertEqual(codec.load("inbox")?.name, "Ntaaa Nnnnat")

        SkeletonMemory.remember("in memory", id: "note")
        XCTAssertEqual(SkeletonMemory.lastShown(id: "note", as: String.self), "in memory")

        forgetSkeletonShapes()
        XCTAssertNil(codec.load("inbox"))
        XCTAssertNil(SkeletonMemory.lastShown(id: "note", as: String.self))
    }

    func testShapesThatNoLongerDecodeAreNotKept() {
        // "pro" scrubs to "ntn", which isn't a Tier, so nothing is stored.
        ShapeCodec<Plan>.codable.save(Plan(tier: .pro), "plan")
        XCTAssertNil(defaults.data(forKey: SkeletonMemory.defaultsPrefix + "plan"))
    }

    func testSampleTemplateKeepsShapeAndReplacesValues() {
        let text = SampleTemplate.describe(Account(name: "Ada Lovelace", balance: 3.5, followers: 42, verified: true, tags: ["x"]))
        XCTAssertTrue(text.hasPrefix("Account("))
        XCTAssertTrue(text.contains("name: \"Nna Enaalaaa\""))
        XCTAssertTrue(text.contains("followers: 88"))
        XCTAssertTrue(text.contains("verified: true"))
        XCTAssertFalse(text.contains("Ada"))
    }
}
