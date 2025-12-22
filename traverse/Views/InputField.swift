//
//  InputField.swift
//  traverse
//

import SwiftUI

struct InputField: View {
    let label: String
    @Binding var value: String
    let keyboardType: UIKeyboardType
    var state: FieldState
    let action: () -> Void
    
    @FocusState.Binding var keyboardShown: Bool
    @State private var isSecure: Bool = false
    @State private var submitTapped = 0
    
    private var isValid: Bool {
        return !value.isEmpty
    }
    
    private var isDisabled: Bool {
        state == .success || state == .loading
    }
    
    var body: some View {
        HStack {
            Group {
                if isSecure && label.lowercased().contains("password") {
                    SecureField(label, text: $value, prompt: Text(label).foregroundStyle(.black.opacity(0.4)))
                } else {
                    TextField(label, text: $value, prompt: Text(label).foregroundStyle(.black.opacity(0.4)))
                }
            }
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.black.opacity(state == .success ? 0.4 : 1))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(keyboardType)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .focused($keyboardShown)
            .disabled(state == .success || state == .loading)
            
            Button {
                if state != .loading {                    let haptic = UIImpactFeedbackGenerator(style: .medium)
                    haptic.impactOccurred();                    action()
                }
            } label: {
                switch state {
                case .loading:
                    ProgressView()
                        .tint(.white)
                default:
                    Image(systemName: "arrow.right")
                }
            }
            .font(.system(size: 24, weight: .bold))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .foregroundStyle(.white)
            .background(.black.opacity((isValid && state != .success) ? 1 : 0.2))
            .clipShape(RoundedRectangle(cornerRadius: .infinity))
            .disabled(!isValid || state == .success || state == .loading)
        }
        .padding(.leading, 24)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .overlay {
            RoundedRectangle(cornerRadius: .infinity)
                .stroke(.black.opacity(0.1), lineWidth: 1)
        }
        .onAppear {
            // Automatically detect if this is a password field
            isSecure = label.lowercased().contains("password")
        }
    }
}
