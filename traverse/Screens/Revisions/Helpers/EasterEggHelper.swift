import SwiftUI
import CoreMotion

struct EasterEggHelper {
    static let quotes = [
        "Resting today makes memory stronger tomorrow. Go conquer those exams! 🎓✨",
        "Sharpening the sword before battle! Revisions will be waiting for your victorious return. ⚔️🧠",
        "Brains need off-time too. Good luck with your study grind! 📚🔥",
        "System offline for high-priority exam prep! Battery charging... ⚡️🔋",
        "Knowledge is consolidating in long-term memory storage... 💾💭",
        "Take a breather! Algorithms can wait, your exams come first! 🏆🚀",
        "Future coding grandmaster in exam mode! 🌟💻"
    ]

    static let patterns = [
        "(⌐■_■)  [ EXAM MODE ACTIVE ]",
        "🧠 ⚡️ 📚  [ BRAIN CHARGING ]",
        "🏖️ 🌴 ☕️  [ REVISIONS PAUSED ]",
        "✨ 🎓 🏆  [ CONQUER YOUR EXAMS ]"
    ]

    static func getTodayEasterEggMessage(date: Date = Date()) -> (pattern: String, quote: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)

        var hash: Int32 = 0
        for char in dateStr.unicodeScalars {
            hash = (hash &<< 5) &- hash &+ Int32(char.value)
        }
        let index = Int(abs(hash))

        let quote = quotes[index % quotes.count]
        let pattern = patterns[index % patterns.count]

        return (pattern, quote)
    }
}

// MARK: - Exam Mode Active View
