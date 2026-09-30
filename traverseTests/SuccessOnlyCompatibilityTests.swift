import Foundation
import XCTest
@testable import traverse

final class SuccessOnlyCompatibilityTests: XCTestCase {
    func testStatsStillDecodeInstalledAppResponseFields() throws {
        let data = Data(#"{"stats":{"total":8,"accepted":8,"failed":0,"acceptanceRate":"100.00%","languageBreakdown":[]}}"#.utf8)
        let stats = try JSONDecoder().decode(SubmissionStats.self, from: data)
        XCTAssertEqual(stats.stats.total, 8)
        XCTAssertEqual(stats.stats.accepted, 8)
    }

    func testOldCachedLapseFieldsAreIgnored() throws {
        let base = #""problemId":1,"problemTitle":"Two Sum","problemSlug":"two-sum","platform":"leetcode","difficulty":"easy","retrievability":0.8,"stability":10,"difficulty_D":3"#
        for extra in [#", "lapses":9,"isLeech":true"#, #", "lapses":0,"isLeech":false"#, ""] {
            let data = Data("{\(base)\(extra)}".utf8)
            let item = try JSONDecoder().decode(RevisionRetentionItem.self, from: data)
            XCTAssertEqual(item.problemId, 1)
            XCTAssertEqual(item.retrievability, 0.8)
        }
    }
}
