import Foundation

class NetworkService {
    static let shared = NetworkService()

    /// Authenticated responses stay in the app's explicit model cache instead of
    /// being duplicated in URLCache or shared across account changes.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()
    
    let baseURL = "https://neatness-enlarged-curled.ngrok-free.dev/api"
    
    private init() {}
    
    // MARK: - Calendar Feed URL
    func calendarFeedURL(username: String, token: String) -> URL? {
        let webcalBase = baseURL.replacingOccurrences(of: "^https?://", with: "webcal://", options: .regularExpression)
        let urlString = "\(webcalBase)/revisions/calendar/\(username)?token=\(token)"
        return URL(string: urlString)
    }
    

}
