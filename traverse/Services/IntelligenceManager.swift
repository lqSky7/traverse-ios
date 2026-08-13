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
        initSession()
    }
    
    private func initSession() {
        if SystemLanguageModel.default.isAvailable {
            session = LanguageModelSession(instructions: systemPrompt)
        }
    }
    
    private var systemPrompt: String {
        """
        You are a concise DSA & LeetCode AI mentor in the Traverse app. Analyze code attempts and error patterns for revision problems.
        RULES:
        1. Output ONLY 1 to 3 plain conversational sentences of technical hint or comparison.
        2. NEVER output JSON, code blocks (` ``` `), backticks, or preamble phrases (such as "Analyze the mistake tags and summary.").
        3. Ignore typos, syntax slips, and silly formatting errors. Never use emojis.
        """
    }
    
    // MARK: - Single Revision Problem Hint (Pending Revision)
    func generateRevisionHintForPending(
        problemTitle: String,
        difficulty: String,
        attempts: [CodeAttempt],
        mistakeTags: [String]?,
        aiAnalysis: String?
    ) async -> String {
        var cleanSummary = aiAnalysis ?? "None"
        if cleanSummary.contains("```") || cleanSummary.contains("{") {
            cleanSummary = cleanAIFeedbackOutput(cleanSummary)
        }
        
        var context = """
        Problem: \(problemTitle) (\(difficulty.capitalized))
        Mistake Tags: \((mistakeTags ?? []).joined(separator: ", "))
        Previous Analysis: \(cleanSummary)
        
        Historical Code Iterations (failed attempts & final correct):
        """
        
        if attempts.isEmpty {
            context += "\n(No raw attempt code stored; rely on mistake tags and summary)"
        } else {
            for (idx, att) in attempts.enumerated() {
                let status = att.successful == true ? "Accepted" : "Failed"
                let codeSnippet = String((att.code ?? "").prefix(800))
                context += "\nAttempt #\(idx + 1) [\(att.type ?? "code"), \(status)]:\n\(codeSnippet)\n"
            }
        }
        
        context += """
        
        INSTRUCTION:
        State the main algorithmic/logic mistake made in previous attempts and give a 2-sentence actionable hint to avoid repeating it today. Output ONLY plain text sentences. No JSON. No code fences. No preamble.
        """
        
        do {
            if session == nil { initSession() }
            guard let activeSession = session else {
                return "Watch out for edge cases and boundary conditions when attempting this problem today."
            }
            let response = try await activeSession.respond(to: context)
            return cleanAIFeedbackOutput(response.content)
        } catch {
            return "Watch out for edge cases and boundary conditions when attempting this problem today."
        }
    }
    
    // MARK: - Single Revision Problem Comparison (Completed/Attempted Revision Today)
    func generateRevisionComparisonForCompleted(
        problemTitle: String,
        difficulty: String,
        previousAttempts: [CodeAttempt],
        todayAttempts: [CodeAttempt],
        mistakeTags: [String]?
    ) async -> String {
        var context = """
        Problem: \(problemTitle) (\(difficulty.capitalized))
        Mistake Tags: \((mistakeTags ?? []).joined(separator: ", "))
        
        Previous Historical Attempts:
        """
        
        if previousAttempts.isEmpty {
            context += "\n(No historical attempt code stored)"
        } else {
            for (idx, att) in previousAttempts.enumerated() {
                let codeSnippet = String((att.code ?? "").prefix(800))
                context += "\nPrev #\(idx + 1):\n\(codeSnippet)\n"
            }
        }
        
        context += "\nToday's Attempt Code:"
        if todayAttempts.isEmpty {
            context += "\n(Completed today)"
        } else {
            for (idx, att) in todayAttempts.enumerated() {
                let codeSnippet = String((att.code ?? "").prefix(800))
                let status = att.successful == true ? "Accepted" : "Failed"
                context += "\nToday #\(idx + 1) [\(status)]:\n\(codeSnippet)\n"
            }
        }
        
        context += """
        
        INSTRUCTION:
        Compare today's code against previous attempt history. Output ONLY 2 plain text sentences answering if the user repeated the same mistake or solved it cleanly. No JSON. No code fences. No preamble.
        """
        
        do {
            if session == nil { initSession() }
            guard let activeSession = session else {
                return "Compare your code logic against previous attempt history."
            }
            let response = try await activeSession.respond(to: context)
            return cleanAIFeedbackOutput(response.content)
        } catch {
            print("[Intelligence] Comparison error: \(error)")
            return "Check your implementation logic to ensure previous edge cases were resolved."
        }
    }
    
    // MARK: - Output Sanitizer Helper
    func cleanAIFeedbackOutput(_ raw: String) -> String {
        var text = raw
        
        // Remove ```json ... ``` blocks
        if let jsonRegex = try? NSRegularExpression(pattern: "```(?:json)?\\s*\\{[\\s\\S]*?\\}\\s*```", options: [.caseInsensitive]) {
            text = jsonRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        
        // Remove raw { ... } JSON structures if any remain
        if let braceRegex = try? NSRegularExpression(pattern: "\\{[\\s\\S]*?\\}", options: []) {
            text = braceRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        
        // Remove preamble phrases
        let preambles = [
            "Analyze the mistake tags and summary.",
            "Analyze mistake tags and summary.",
            "INSTRUCTION:",
            "Analyze the exact logic/algorithmic mistake made in previous attempts."
        ]
        for preamble in preambles {
            text = text.replacingOccurrences(of: preamble, with: "", options: [.caseInsensitive])
        }
        
        // Remove stray code block backticks
        text = text.replacingOccurrences(of: "```", with: "")
        
        // Trim extra spaces and newlines
        let cleanedLines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let result = cleanedLines.joined(separator: "\n\n")
        return result.isEmpty ? "Review past attempts carefully to resolve edge case logic errors." : result
    }
    
    func reset() {
        state = .idle
    }
}
