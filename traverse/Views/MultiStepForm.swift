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
                                    currentStep -= 1
                                    gradient = colorScheme == .dark ? steps[currentStep].darkGradient : steps[currentStep].lightGradient
                                    steps[currentStep + 1].state = .idle
                                    steps[currentStep + 1].answer = ""
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
                        InputField(
                            label: placeholder,
                            value: $steps[currentStep].answer,
                            keyboardType: keyboardType,
                            state: steps[currentStep].state,
                            action: submitCurrentStep,
                            keyboardShown: $keyboardShown
                        )
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
