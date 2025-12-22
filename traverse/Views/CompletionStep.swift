//
//  CompletionStep.swift
//  traverse
//

import SwiftUI

struct CompletionStep: View {
    let title: String
    let description: String
    
    let completionTitle: String
    let completionDescription: String
    
    let onSubmit: () async throws -> Void
    let onComplete: () -> Void
    
    @State private var isCompleted = false
    @State private var isInProgress = false
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
                Text(hasError ? "Error" : isCompleted ? completionTitle : title)
                    .id(isCompleted)
                    .font(.system(size: 24))
                    .bold()
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: 30).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                
                Text(hasError ? errorMessage : isCompleted ? completionDescription : description)
                    .id(isCompleted)
                    .foregroundStyle(.black.opacity(0.3))
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
                    try await onSubmit()
                    
                    withAnimation(.bouncy(duration: 1)) {
                        isCompleted = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        onComplete()
                    }
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
