//
//  RevisionCoachSheet.swift
//  traverse
//
//  1:1 reproduction of radiofun/BottomGradientShader with Liquid Glass (.glassEffect)
//  on ALL interactive icons (Code History, AI Sparkles, and Error Tags).
//

import SwiftUI

struct RevisionCoachSheet: View {
    let revision: Revision
    let solve: Solve?
    let todaySolve: Solve?
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var fetchedRevision: Revision? = nil
    @State private var aiFeedbackText: String? = nil
    @State private var isLoading = false
    @State private var showingHistorySheet = false
    @State private var selectedTooltipTag: String? = nil

    // Haptic Generator
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    // Intro entrance animation state (runs ONCE on sheet open)
    @State private var lightReveal: CGFloat = 0
    @State private var isIntroVisible = false

    // Subtle & silky-smooth text morph state
    @State private var isTextVisible = true
    @State private var currentStepIndex = 0

    private let loadingSteps = [
        "Fetching backend data...",
        "Loading model & parameters...",
        "Analyzing code execution patterns...",
        "Formulating AI revision hint..."
    ]

    private var activeRevision: Revision {
        fetchedRevision ?? revision
    }

    private var activeSolve: Solve? {
        if let solveFromRev = activeRevision.solve {
            let problem = Problem(
                platform: activeRevision.problem.platform,
                slug: activeRevision.problem.slug,
                title: activeRevision.problem.title,
                difficulty: activeRevision.problem.difficulty,
                category: activeRevision.problem.category,
                topic: activeRevision.problem.topic,
                subtopic: activeRevision.problem.subtopic
            )
            let submission = Submission(
                language: "unknown",
                happenedAt: solveFromRev.solvedAt,
                aiAnalysis: solveFromRev.aiAnalysis,
                mistakeTags: solveFromRev.mistakeTags,
                numberOfTries: nil,
                timeTaken: nil,
                attempts: solveFromRev.attempts
            )
            return Solve(
                id: solveFromRev.id,
                xpAwarded: solveFromRev.xpAwarded,
                solvedAt: solveFromRev.solvedAt,
                aiAnalysis: solveFromRev.aiAnalysis,
                mistakeTags: solveFromRev.mistakeTags,
                attempts: solveFromRev.attempts,
                problem: problem,
                submission: submission,
                highlight: nil
            )
        }
        return solve
    }

    private var isCompletedToday: Bool {
        activeRevision.isCompleted || todaySolve != nil
    }

    private var previousAttempts: [CodeAttempt] {
        activeSolve?.allAttempts ?? []
    }

    private var todayAttempts: [CodeAttempt] {
        todaySolve?.allAttempts ?? []
    }

    private var mistakeTags: [String] {
        let tags = activeSolve?.mistakeTags ?? activeSolve?.submission.mistakeTags ?? []
        if tags.isEmpty {
            return ["Logic Bug", "Edge Case", "Time Limit Exceeded"]
        }
        return tags
    }

    private var currentDisplayText: String {
        if isLoading {
            return loadingSteps[currentStepIndex % loadingSteps.count]
        } else if let feedback = aiFeedbackText {
            return feedback
        } else {
            return "Preparing AI analysis..."
        }
    }

    // Guaranteed valid & distinct SF Symbols
    private func iconForTag(_ tag: String, index: Int) -> String {
        let lower = tag.lowercased()
        if lower.contains("syntax") || lower.contains("type") { return "curlybraces" }
        if lower.contains("logic") || lower.contains("bug") {
            let logicIcons = [
                "ladybug.fill",
                "ant.fill",
                "gearshape.fill",
                "brain.head.profile",
                "lightbulb.fill"
            ]
            return logicIcons[index % logicIcons.count]
        }
        if lower.contains("boundary") || lower.contains("edge") || lower.contains("index") { return "exclamationmark.triangle.fill" }
        if lower.contains("time") || lower.contains("timeout") || lower.contains("loop") { return "hourglass" }
        if lower.contains("memory") || lower.contains("space") { return "cpu" }

        let fallbackIcons = [
            "ladybug.fill",
            "exclamationmark.triangle.fill",
            "curlybraces",
            "hourglass",
            "flame.fill",
            "bolt.fill",
            "cpu",
            "brain",
            "wrench.and.screwdriver.fill",
            "terminal.fill"
        ]
        return fallbackIcons[index % fallbackIcons.count]
    }

    // Returns unique shape & size definitions for each floating icon
    private func iconStyle(for index: Int) -> (width: CGFloat, height: CGFloat, cornerRadius: CGFloat, isCircle: Bool, isCapsule: Bool) {
        let styles: [(CGFloat, CGFloat, CGFloat, Bool, Bool)] = [
            (62, 48, 24, false, true),   // Wide capsule
            (54, 54, 27, true, false),   // Circle
            (48, 58, 16, false, false),  // Vertical rect
            (60, 46, 12, false, false),  // Wide rect
            (52, 52, 18, false, false),  // Squircle
            (56, 44, 22, false, true)    // Capsule
        ]
        return styles[index % styles.count]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                // 1:1 Bottom Ambient Light Background Shader
                BottomAmbientLightView(tint: paletteManager.color(at: 3), progress: lightReveal)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        // 1. Organic Floating Icons Cluster (ALL Liquid Glass)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 24) {
                                // Code History Icon Button (Liquid Glass)
                                Button {
                                    impactFeedback.impactOccurred()
                                    showingHistorySheet = true
                                } label: {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(paletteManager.color(at: 1))
                                        .frame(width: 62, height: 48)
                                        .glassEffect(.regular, in: .capsule)
                                }
                                .offset(y: -8)

                                // Error Tag Icons (ALL Liquid Glass with distinct shapes & active tinting)
                                ForEach(Array(mistakeTags.enumerated()), id: \.offset) { idx, tag in
                                    let style = iconStyle(for: idx + 1)
                                    let isSelected = selectedTooltipTag == tag
                                    let iconColor = paletteManager.color(at: (idx + 2) % 5)

                                    Button {
                                        impactFeedback.impactOccurred()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            if selectedTooltipTag == tag {
                                                selectedTooltipTag = nil
                                            } else {
                                                selectedTooltipTag = tag
                                            }
                                        }
                                    } label: {
                                        Group {
                                            if style.isCircle {
                                                Image(systemName: iconForTag(tag, index: idx))
                                                    .font(.system(size: 22, weight: .semibold))
                                                    .foregroundStyle(iconColor)
                                                    .frame(width: style.width, height: style.height)
                                                    .glassEffect(
                                                        isSelected ? .regular.tint(iconColor.opacity(0.3)) : .regular,
                                                        in: .circle
                                                    )
                                            } else if style.isCapsule {
                                                Image(systemName: iconForTag(tag, index: idx))
                                                    .font(.system(size: 22, weight: .semibold))
                                                    .foregroundStyle(iconColor)
                                                    .frame(width: style.width, height: style.height)
                                                    .glassEffect(
                                                        isSelected ? .regular.tint(iconColor.opacity(0.3)) : .regular,
                                                        in: .capsule
                                                    )
                                            } else {
                                                Image(systemName: iconForTag(tag, index: idx))
                                                    .font(.system(size: 22, weight: .semibold))
                                                    .foregroundStyle(iconColor)
                                                    .frame(width: style.width, height: style.height)
                                                    .glassEffect(
                                                        isSelected ? .regular.tint(iconColor.opacity(0.3)) : .regular,
                                                        in: .rect(cornerRadius: style.cornerRadius)
                                                    )
                                            }
                                        }
                                        .scaleEffect(isSelected ? 1.15 : 1.0)
                                    }
                                    .offset(y: CGFloat((idx % 2 == 0) ? 8 : -10))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        .frame(height: 112)

                        // 2. Liquid Glass Tooltip Banner
                        if let activeTag = selectedTooltipTag {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(paletteManager.color(at: 2))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("RECORDED MISTAKE PATTERN")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white.opacity(0.6))
                                    Text(activeTag)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }

                                Spacer()

                                Button {
                                    withAnimation { selectedTooltipTag = nil }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // 3. AI Sparkles Icon DIRECTLY ABOVE AI Revision Hint & Text Area (Liquid Glass)
                        VStack(spacing: 12) {
                            Button {
                                impactFeedback.impactOccurred()
                            } label: {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(paletteManager.color(at: 3))
                                    .frame(width: 64, height: 64)
                                    .glassEffect(.regular, in: .circle)
                            }

                            Text(isCompletedToday ? "AI ATTEMPT COMPARISON" : "AI REVISION HINT")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.35))

                            ScrollView(.vertical, showsIndicators: false) {
                                Text(currentDisplayText)
                                    .font(isLoading ? .headline : .subheadline)
                                    .fontWeight(isLoading ? .medium : .regular)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                                    .padding(.horizontal, 16)
                                    .opacity(isTextVisible ? 1 : 0)
                                    .blur(radius: isTextVisible ? 0 : 6)
                            }
                            .frame(maxHeight: 180)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
                    .opacity(isIntroVisible ? 1 : 0)
                    .blur(radius: isIntroVisible ? 0 : 28)
                    .offset(y: isIntroVisible ? -40 : 62)
                    .scaleEffect(isIntroVisible ? 1 : 0.96, anchor: .bottom)
                }
            }
            .navigationTitle("\(revision.problem.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showingHistorySheet) {
                AttemptCodeHistorySheet(
                    problemTitle: revision.problem.title,
                    previousAttempts: previousAttempts,
                    todayAttempts: todayAttempts,
                    paletteManager: paletteManager
                )
            }
            .task {
                impactFeedback.prepare()
                await startAIFeedbackFlow()
            }
        }
    }

    @MainActor
    private func playIntroSequence() async {
        lightReveal = 0
        isIntroVisible = false

        guard !reduceMotion else {
            lightReveal = 1
            isIntroVisible = true
            return
        }

        // 1:1 intro animation timeline
        try? await Task.sleep(nanoseconds: 120_000_000)
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 1.15)) {
            lightReveal = 1
        }

        try? await Task.sleep(nanoseconds: 280_000_000)
        guard !Task.isCancelled else { return }

        withAnimation(.spring(duration: 0.78, bounce: 0.16)) {
            isIntroVisible = true
        }

        try? await Task.sleep(nanoseconds: 680_000_000)
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.8)) {
            lightReveal = 0.82
        }
    }

    @MainActor
    private func advanceTextWithBlurMorph(action: () -> Void) async {
        withAnimation(.easeInOut(duration: 0.22)) {
            isTextVisible = false
        }
        try? await Task.sleep(nanoseconds: 180_000_000)
        action()
        withAnimation(.easeInOut(duration: 0.35)) {
            isTextVisible = true
        }
    }

    @MainActor
    private func startAIFeedbackFlow() async {
        guard !isLoading else { return }
        isLoading = true

        // Play 1:1 Intro Sequence ONCE when sheet opens
        await playIntroSequence()

        // Lazy-fetch full revision details (attempts, AI analysis, problem topics) on-demand
        if fetchedRevision == nil {
            if let details = try? await NetworkService.shared.fetchRevisionDetails(id: revision.id) {
                self.fetchedRevision = details.revision
            }
        }

        // Fetch AI Response in background task
        let fetchTask = Task<String?, Never> {
            if #available(iOS 18.2, *) {
                let manager = IntelligenceManager.shared
                let rawResult: String
                if isCompletedToday {
                    rawResult = await manager.generateRevisionComparisonForCompleted(
                        problemTitle: activeRevision.problem.title,
                        difficulty: activeRevision.problem.difficulty,
                        previousAttempts: previousAttempts,
                        todayAttempts: todayAttempts,
                        mistakeTags: mistakeTags
                    )
                } else {
                    rawResult = await manager.generateRevisionHintForPending(
                        problemTitle: activeRevision.problem.title,
                        difficulty: activeRevision.problem.difficulty,
                        attempts: previousAttempts,
                        mistakeTags: mistakeTags,
                        aiAnalysis: activeSolve?.aiAnalysis ?? activeSolve?.submission.aiAnalysis
                    )
                }
                return manager.cleanAIFeedbackOutput(rawResult)
            } else {
                return "Review past failed attempts carefully to avoid repeating edge case mistakes."
            }
        }

        // Step through loading text with fast, silky-smooth 6pt soft blur morph animation
        currentStepIndex = 0
        let minSteps = 2
        var stepsExecuted = 0

        while isLoading {
            let fetchedText = await fetchTask.value
            if stepsExecuted >= minSteps, let text = fetchedText {
                await advanceTextWithBlurMorph {
                    self.aiFeedbackText = text
                    self.isLoading = false
                }
                break
            }

            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard isLoading else { break }

            await advanceTextWithBlurMorph {
                self.currentStepIndex += 1
            }
            stepsExecuted += 1
        }
    }
}
