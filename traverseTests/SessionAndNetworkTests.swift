import Foundation
import XCTest
@testable import traverse

@MainActor
final class KeychainHelperTests: XCTestCase {
    func testTokenCanBeCreatedUpdatedAndDeleted() {
        let store = KeychainHelper(service: "com.traverse.tests.\(UUID().uuidString)")
        defer { store.deleteToken() }

        XCTAssertTrue(store.saveToken("first-token"))
        XCTAssertEqual(store.getToken(), "first-token")
        XCTAssertTrue(store.saveToken("second-token"))
        XCTAssertEqual(store.getToken(), "second-token")

        store.deleteToken()
        XCTAssertNil(store.getToken())
    }
}

@MainActor
final class DataManagerLogoutTests: XCTestCase {
    func testClearAllDataRemovesPersistedAccountCache() throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cachedFiles = [
            "friends.json", "receivedRequests.json", "sentRequests.json",
            "receivedStreakRequests.json", "sentStreakRequests.json", "friendStreaks.json",
            "userStats.json", "submissionStats.json", "solveStats.json", "achievementStats.json",
            "recentSolves.json", "todayRevisions.json", "completedRevisions.json",
            "lastFetchTimestamp.json", "revisionGroups.json", "revisionStats.json",
            "revisionScore.json"
        ]
        for name in cachedFiles {
            try Data("account-data".utf8).write(to: documents.appendingPathComponent(name))
        }

        DataManager.shared.clearAllData()

        for name in cachedFiles {
            let fileURL = documents.appendingPathComponent(name)
            XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "\(name) should clear at logout")
        }
        XCTAssertNil(DataManager.shared.userStats)
        XCTAssertTrue(DataManager.shared.friends.isEmpty)
        XCTAssertFalse(DataManager.shared.hasData)
    }
}

@MainActor
final class NetworkSessionIntegrationTests: XCTestCase {
    func testBillingAndLogoutUseAuthenticatedNoCacheSession() async throws {
        let store = KeychainHelper(service: "com.traverse.tests.\(UUID().uuidString)")
        XCTAssertTrue(store.saveToken("integration-token"))
        defer { store.deleteToken() }

        let requests = RequestRecorder()
        let session = makeStubSession(recording: requests)
        defer { session.invalidateAndCancel() }
        defer { StubURLProtocol.handler = nil }

        let service = NetworkService(
            session: session,
            baseURL: "https://api.example.test/api",
            keychain: store
        )
        let status = try await service.getSubscriptionStatus()
        XCTAssertTrue(status.isSubscriptionActive)
        XCTAssertEqual(status.planName, "Traverse Pro")
        _ = try await service.cancelSubscription()
        try await service.logout()

        let recorded = requests.values
        XCTAssertEqual(recorded.map { $0.httpMethod ?? "" }, ["GET", "POST", "POST"])
        XCTAssertEqual(recorded.map { $0.url?.path ?? "" }, [
            "/api/subscription/status", "/api/subscription/cancel", "/api/auth/logout"
        ])
        XCTAssertTrue(recorded.allSatisfy {
            $0.value(forHTTPHeaderField: "Authorization") == "Bearer integration-token"
        })
        XCTAssertNil(store.getToken())
    }

    private func makeStubSession(recording requests: RequestRecorder) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            requests.append(request)
            let path = request.url?.path ?? ""
            let body: String
            if path.hasSuffix("/subscription/status") {
                body = """
                    {
                      "isSubscriptionActive": true,
                      "activeUntil": "2026-10-01T00:00:00.000Z",
                      "planName": "Traverse Pro",
                      "canCancel": true,
                      "cancellationScheduled": false
                    }
                    """
            } else if path.hasSuffix("/subscription/cancel") {
                body = """
                    {"success":true,"cancelAt":"2026-10-01T00:00:00.000Z"}
                    """
            } else {
                body = "{}"
            }
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(body.utf8))
        }
        return URLSession(configuration: configuration)
    }
}

private final class RequestRecorder {
    private let lock = NSLock()
    private var stored: [URLRequest] = []

    var values: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func append(_ request: URLRequest) {
        lock.lock()
        stored.append(request)
        lock.unlock()
    }
}

private class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.unsupportedURL) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
