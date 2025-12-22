//
//  CompletionStep.swift
//  traverse
//

import SwiftUI

struct CompletionStep: View {
    let title: String
    let description: String
    
    let loadingTitle: String?
    let loadingDescription: String?
    
    let completionTitle: String
    let completionDescription: String
    
    let onSubmit: () async throws -> Void
    let onFetchData: (() async throws -> Void)?
    let onComplete: () -> Void
    
    @State private var isCompleted = false
    @State private var isInProgress = false
    @State private var isFetchingData = false
    @State private var hasError = false
    @State private var errorMessage = ""
    
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            Image(systemName: hasError ? "xmark.circle.fill" : isCompleted ? "checkmark.circle.fill" : "circle.dashed")
                .id(isCompleted)
                .rotationEffect(.degrees(isCompleted ? 0 : isInProgress && !hasError ? 360 : 0))
                .font(.system(size: 24))
                .foregroundStyle(hasError ? .red : isCompleted ? .green : .purple)
                .transition(.scale)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(hasError ? "Error" : isCompleted ? completionTitle : isFetchingData ? (loadingTitle ?? title) : title)
                    .id("\(isCompleted)-\(isFetchingData)")
                    .font(.system(size: 24))
                    .bold()
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: 30).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                
                Text(hasError ? errorMessage : isCompleted ? completionDescription : isFetchingData ? (loadingDescription ?? description) : description)
                    .id("\(isCompleted)-\(isFetchingData)")
                    .foregroundStyle(Color.primary.opacity(0.3))
                    .fontWeight(.medium)
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: 30).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
            .drawingGroup()
        }
        .onAppear {
            withAnimation(.linear(duration: 1).speed(0.3).repeatForever(autoreverses: false)) {
                isInProgress = true
            }
            
            Task {
                do {
                    // Step 1: Initial submission (e.g., login)
                    try await onSubmit()
                    
                    // Wait for animation to be visible
                    try await Task.sleep(nanoseconds: 800_000_000)
                    
                    // Step 2: Fetch data if provided
                    if let onFetchData = onFetchData {
                        withAnimation(.smooth(duration: 0.4)) {
                            isFetchingData = true
                        }
                        
                        try await Task.sleep(nanoseconds: 400_000_000)
                        try await onFetchData()
                        
                        // Wait to show the fetching state
                        try await Task.sleep(nanoseconds: 800_000_000)
                    }
                    
                    // Step 3: Show completion
                    withAnimation(.bouncy(duration: 1)) {
                        isCompleted = true
                    }
                    
                    // Wait before transitioning to next screen
                    try await Task.sleep(nanoseconds: 1_200_000_000)
                    
                    // Call onComplete which will trigger the authentication state change
                    onComplete()
                } catch {
                    withAnimation(.bouncy(duration: 1)) {
                        hasError = true
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
