import Foundation

class NetworkService {
    static let shared = NetworkService()

    /// Authenticated responses stay in the app's explicit model cache instead of
    /// being duplicated in URLCache or shared across account changes.
    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }
    
    let baseURL: String
    let session: URLSession
    let keychain: KeychainHelper
    
    init(
        session: URLSession? = nil,
        baseURL: String = "https://neatness-enlarged-curled.ngrok-free.dev/api",
        keychain: KeychainHelper = .shared
    ) {
        self.session = session ?? Self.makeSession()
        self.baseURL = baseURL
        self.keychain = keychain
    }
    
    // MARK: - Calendar Feed URL
    func calendarFeedURL(username: String, token: String) -> URL? {
        let webcalBase = baseURL.replacingOccurrences(of: "^https?://", with: "webcal://", options: .regularExpression)
        let urlString = "\(webcalBase)/revisions/calendar/\(username)?token=\(token)"
        return URL(string: urlString)
    }
    

}
