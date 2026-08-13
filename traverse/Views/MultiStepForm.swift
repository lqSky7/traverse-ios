//
//  MultiStepForm.swift
//  traverse
//

import SwiftUI

enum FieldState {
    case idle
    case loading
    case success
    case error
}

enum StepType {
    case inputField(placeholder: String, keyboardType: UIKeyboardType)
    case button(title: String, icon: String)
    case huePicker
}

public struct FormStep: Identifiable {
    public let id = UUID()
    let icon: String
    let title: String
    let description: String

    let type: StepType
    let lightGradient: (Color, Color, Color)
    let darkGradient: (Color, Color, Color)

    let onSubmit: (String) async throws -> Void
    var state: FieldState = .idle

    var answer: String = ""
    var forgotPasswordAction: (() async throws -> [FormStep])? = nil
}

struct MultiStepForm: View {
    @State var steps: [FormStep]
    @State private var currentStep = 0
    @State private var backTapped = 0
    @State private var submitTapped = 0

    let completionStep: CompletionStep

    @Binding var gradient: (Color, Color, Color)
    @FocusState.Binding var keyboardShown: Bool
    let onBack: () -> Void
    
    @Environment(\.colorScheme) var colorScheme

    private var hasFinishedForm: Bool {
        currentStep >= steps.count
    }

    var body: some View {
        ZStack {
            // Back button
            if !hasFinishedForm {
                VStack {
                    HStack {
                        Button(action: {
                            backTapped += 1

                            if currentStep > 0 {
                                withAnimation(.smooth(duration: 0.5)) {
                                    let targetStep = currentStep - 1
                                    
                                    // If going back to the step that has forgotPasswordAction, discard any subsequent appended steps
                                    if steps[targetStep].forgotPasswordAction != nil {
                                        steps = Array(steps.prefix(targetStep + 1))
                                    } else {
                                        steps[currentStep].state = .idle
                                        steps[currentStep].answer = ""
                                    }
                                    
                                    currentStep = targetStep
                                    gradient = colorScheme == .dark ? steps[currentStep].darkGradient : steps[currentStep].lightGradient
                                    steps[currentStep].state = .idle
                                }
                            } else {
                                onBack()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(12)
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: backTapped)
                        .glassEffect(.regular.interactive(), in: .circle)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    Spacer()
                }
            }

            VStack (spacing: 64) {
                VStack(alignment: .leading, spacing: 32) {
                    ForEach(steps, id: \.id) { step in
                        Step(
                            icon: step.icon,
                            gradient: colorScheme == .dark ? step.darkGradient : step.lightGradient,
                            title: step.title,
                            description: step.description,
                            isExpanded: !hasFinishedForm && step.id == steps[currentStep].id
                        )
                    }

                    ZStack {
                        if hasFinishedForm {
                            CompletionStep(
                                title: completionStep.title,
                                description: completionStep.description,
                                loadingTitle: completionStep.loadingTitle,
                                loadingDescription: completionStep.loadingDescription,
                                completionTitle: completionStep.completionTitle,
                                completionDescription: completionStep.completionDescription,
                                onSubmit: completionStep.onSubmit,
                                onFetchData: completionStep.onFetchData,
                                onComplete: completionStep.onComplete
                            )
                            .transition(.offset(y: 40).combined(with: .opacity))
                        }
                    }
                    .animation(.default.delay(0.4), value: hasFinishedForm)
                }

                if !hasFinishedForm {
                    switch steps[currentStep].type {
                    case .button(let title, let icon):
                        ContinueButton(
                            title: title,
                            icon: icon,
                            action: submitCurrentStep,
                            state: steps[currentStep].state
                        )
                        .animation(.none, value: currentStep)
                    case .inputField(let placeholder, let keyboardType):
                        VStack(alignment: .leading, spacing: 12) {
                            InputField(
                                label: placeholder,
                                value: $steps[currentStep].answer,
                                keyboardType: keyboardType,
                                state: steps[currentStep].state,
                                action: submitCurrentStep,
                                keyboardShown: $keyboardShown
                            )
                            
                            if let forgotAction = steps[currentStep].forgotPasswordAction {
                                Button(action: {
                                    Task {
                                        await handleForgotPassword(action: forgotAction)
                                    }
                                }) {
                                    Text("Forgot password?")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color.primary.opacity(0.6))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 8)
                                }
                                .padding(.leading, 24)
                                .disabled(steps[currentStep].state == .loading)
                            }
                        }
                    case .huePicker:
                        VStack(spacing: 24) {
                            HuePicker()
                            
                            ContinueButton(
                                title: "Continue",
                                icon: "arrow.right",
                                action: submitCurrentStep,
                                state: steps[currentStep].state
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: hasFinishedForm ? .center : .bottomLeading)
            .padding(42)
        }
    }

    private func handleForgotPassword(action: @escaping () async throws -> [FormStep]) async {
        guard currentStep >= 0 && currentStep < steps.count else { return }
        
        steps[currentStep].state = .loading
        keyboardShown = false
        
        do {
            let newSteps = try await action()
            steps[currentStep].state = .success
            
            withAnimation(.smooth(duration: 0.5)) {
                steps.insert(contentsOf: newSteps, at: currentStep + 1)
                currentStep += 1
                gradient = colorScheme == .dark ? steps[currentStep].darkGradient : steps[currentStep].lightGradient
            }
        } catch {
            steps[currentStep].state = .error
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if currentStep < steps.count {
                steps[currentStep].state = .idle
            }
        }
    }

    private func submitCurrentStep() {
        guard currentStep >= 0 && currentStep < steps.count else { return }

        let submitAction = steps[currentStep].onSubmit
        let answer = steps[currentStep].answer

        steps[currentStep].state = .loading
        keyboardShown = false

        let isLastStep = currentStep == steps.count - 1

        Task {
            do {
                try await submitAction(answer)

                steps[currentStep].state = .success

                if isLastStep {
                    gradient = (.clear, .clear, .clear)
                }

                withAnimation(.smooth(duration: 0.5)) {
                    currentStep += 1

                    if !isLastStep {
                        gradient = colorScheme == .dark ? steps[currentStep].darkGradient : steps[currentStep].lightGradient
                    }
                }
            } catch {
                steps[currentStep].state = .error
            }
        }
    }
}
