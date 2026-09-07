import Foundation

class NetworkService {
    static let shared = NetworkService()
    
    let baseURL = "https://neatness-enlarged-curled.ngrok-free.dev/api"
    
    private init() {}
    
    // MARK: - Calendar Feed URL
    func calendarFeedURL(username: String, token: String) -> URL? {
        let webcalBase = baseURL.replacingOccurrences(of: "^https?://", with: "webcal://", options: .regularExpression)
        let urlString = "\(webcalBase)/revisions/calendar/\(username)?token=\(token)"
        return URL(string: urlString)
    }
    

}
