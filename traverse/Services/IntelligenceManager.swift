//
//  IntelligenceManager.swift
//  traverse
//

import Foundation
import FoundationModels
import Combine

@available(iOS 18.2, *)
@MainActor
final class IntelligenceManager: ObservableObject {
    static let shared = IntelligenceManager()
    
    @Published var state: IntelligenceState = .idle
    private var session: LanguageModelSession?
    
    private init() {
        // Initialize session with system instructions
        if SystemLanguageModel.default.isAvailable {
            session = LanguageModelSession(instructions: systemPrompt)
        }
    }
    
    private var systemPrompt: String {
        """
        You are a coding coach for a LeetCode tracking app. Analyze user data and provide personalized advice in 2-3 sentences. Be specific, supportive, and concise. Never use emojis or special characters.
        """
    }
    
    func generateSummary(
        streak: Int,
        solvedToday: Bool,
        totalSolves: Int,
        recentSolves: [Solve],
        difficulty: ProblemsByDifficulty
    ) async {
        print("[Intelligence] Starting generation...")
        print("[Intelligence] System available: \(SystemLanguageModel.default.isAvailable)")
        
        guard SystemLanguageModel.default.isAvailable else {
            state = .error("Apple Intelligence not available on this device")
            return
        }
        
        state = .generating
        
        // Build context from user data
        let context = buildContext(
            streak: streak,
            solvedToday: solvedToday,
            totalSolves: totalSolves,
            recentSolves: recentSolves,
            difficulty: difficulty
        )
        
        print("[Intelligence] Context built:")
        print("Input Data:")
        print("   - Streak: \(streak)")
        print("   - Solved Today: \(solvedToday)")
        print("   - Total Solves: \(totalSolves)")
        print("   - Difficulty: Easy=\(difficulty.easy), Medium=\(difficulty.medium), Hard=\(difficulty.hard)")
        print("   - Recent Solves Count: \(recentSolves.count)")
        print("\nFull Context String:")
        print("─────────────────────────────────────")
        print(context)
        print("─────────────────────────────────────\n")
        
        do {
            guard let session = session else {
                print("[Intelligence] Session not initialized")
                state = .error("Session not initialized")
                return
            }
            
            print("[Intelligence] Sending request to model...")
            let response = try await session.respond(to: context)
            print("[Intelligence] Response received:")
            print("   Content: \(response.content)")
            
            let summary = IntelligenceSummary(
                message: response.content,
                generatedAt: Date(),
                streak: streak,
                totalSolves: totalSolves
            )
            
            state = .ready(summary)
            print("[Intelligence] Summary ready")
            
        } catch {
            print("[Intelligence] Error occurred:")
            print("   Error: \(error)")
            print("   Localized: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Domain: \(nsError.domain)")
                print("   Code: \(nsError.code)")
                print("   UserInfo: \(nsError.userInfo)")
            }
            state = .error("Failed to generate summary: \(error.localizedDescription)")
        }
    }
    
    private func buildContext(
        streak: Int,
        solvedToday: Bool,
        totalSolves: Int,
        recentSolves: [Solve],
        difficulty: ProblemsByDifficulty
    ) -> String {
        var context = """
        Current streak: \(streak) days
        Solved today: \(solvedToday ? "Yes" : "No")
        Total solved: \(totalSolves) problems
        Breakdown: \(difficulty.easy) easy, \(difficulty.medium) medium, \(difficulty.hard) hard
        
        """
        
        // Add recent solve patterns
        if !recentSolves.isEmpty {
            let last5 = Array(recentSolves.prefix(5))
            context += "Recent activity:\n"
            
            for solve in last5 {
                let daysAgo = daysAgoText(from: solve.solvedAt)
                context += "\(solve.problem.difficulty) on \(solve.problem.platform) (\(daysAgo))\n"
            }
            
            // Analyze patterns
            let recentDifficulties = last5.map { $0.problem.difficulty }
            let easyCount = recentDifficulties.filter { $0.lowercased() == "easy" }.count
            let mediumCount = recentDifficulties.filter { $0.lowercased() == "medium" }.count
            let hardCount = recentDifficulties.filter { $0.lowercased() == "hard" }.count
            
            context += "\nRecent mix: \(easyCount) easy, \(mediumCount) medium, \(hardCount) hard\n"
        }
        
        // Add streak context
        if streak >= 7 {
            context += "\nStrong momentum with week-long streak.\n"
        } else if streak > 0 {
            context += "\nBuilding momentum.\n"
        } else {
            context += "\nReady to start a new streak.\n"
        }
        
        // Add urgency if needed
        if streak > 0 && !solvedToday {
            context += "Active streak needs a solve today.\n"
        }
        
        context += """
        
        Provide a personalized 2-3 sentence coaching message. Reference specific numbers. Be supportive and actionable. No emojis.
        """
        
        return context
    }
    
    private func daysAgoText(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else {
            return "recently"
        }
        
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        
        if days == 0 {
            return "today"
        } else if days == 1 {
            return "yesterday"
        } else {
            return "\(days) days ago"
        }
    }
    
    func reset() {
        state = .idle
    }
}
