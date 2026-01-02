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
    @State private var submitTapped = 0
    
    private var isSecure: Bool {
        label.lowercased().contains("password")
    }
    
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
                    SecureField(label, text: $value, prompt: Text(label).foregroundStyle(Color.primary.opacity(0.4)))
                } else {
                    TextField(label, text: $value, prompt: Text(label).foregroundStyle(Color.primary.opacity(0.4)))
                }
            }
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color.primary.opacity(state == .success ? 0.4 : 1))
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
                        .tint(Color(.systemBackground))
                default:
                    Image(systemName: "arrow.right")
                }
            }
            .font(.system(size: 24, weight: .bold))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .foregroundStyle(Color(.systemBackground))
            .background(Color.primary.opacity((isValid && state != .success) ? 1 : 0.2))
            .clipShape(RoundedRectangle(cornerRadius: .infinity))
            .disabled(!isValid || state == .success || state == .loading)
        }
        .padding(.leading, 24)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .overlay {
            RoundedRectangle(cornerRadius: .infinity)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }
}
