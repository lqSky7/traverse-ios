//
//  ContinueButton.swift
//  traverse
//

import SwiftUI

struct ContinueButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var state: FieldState
    
    @State private var buttonTapped = 0
    
    var body: some View {
        Button(action: {
            if state != .loading {
                buttonTapped += 1
                action()
            }
        }) {
            if state == .loading {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: icon)
            }
            
            Text(title)
                .font(.headline)
                .bold()
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.black)
        .cornerRadius(.infinity)
        .sensoryFeedback(.impact(weight: .medium), trigger: buttonTapped)
    }
}
