//
//  MarkdownText.swift
//  traverse
//
//  Rich markdown renderer supporting bold, italic, code, headers, and bullet points in SwiftUI.
//

import SwiftUI

struct MarkdownText: View {
    let markdown: String
    
    private var normalizedMarkdown: String {
        markdown
            .replacingOccurrences(of: "\\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var attributedContent: AttributedString {
        let text = normalizedMarkdown
        
        // 1. Try full markdown parsing
        if let attr = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            return attr
        }
        
        // 2. Try inline-only preserving whitespace
        if let attr = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            return attr
        }
        
        // 3. Fallback to plain string
        return AttributedString(text)
    }
    
    var body: some View {
        Text(attributedContent)
    }
}
