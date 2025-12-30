//
//  IntelligenceModels.swift
//  traverse
//

import Foundation

struct IntelligenceSummary: Codable {
    let message: String
    let generatedAt: Date
    let streak: Int
    let totalSolves: Int
}

enum IntelligenceState {
    case idle
    case generating
    case ready(IntelligenceSummary)
    case error(String)
}
