//
//  EmptyStateView.swift
//  traverse
//
//  One zero state for the whole app.
//
//  Every screen used to answer "there is nothing here yet" in its own way: a
//  bare grey sentence on one, a spinner that never resolved on another, nothing
//  at all on a third. That is the wrong way round here. A new account is
//  *entirely* empty until it solves its first problem in the browser, so the
//  zero state is not an edge case — for most users it is the first screen they
//  actually read. It has exactly one job: say what to do next.
//
//  `EmptyStateView` is the small shared shell. `GettingStartedEmptyState` is
//  the one that matters most: it is what Home, Problems and Revisions show
//  before the first solve lands, and it points at the only two things that can
//  produce data.
//

import SwiftUI

/// Where a brand-new account has to go.
///
/// Nothing in this app can be filled in from inside the app: every solve,
/// attempt and revision arrives from the browser extension. These are the only
/// two URLs a zero state ever needs.
enum TraverseLinks {
    /// The install-and-sign-in page. Explains the extension and links the store.
    static let downloads = URL(string: "https://leet-feedback.vercel.app/downloads")!
    /// Direct store listing, for a user who already knows what they want.
    static let extensionStore = URL(
        string: "https://chromewebstore.google.com/detail/traverse/nnapafjmoelkehjedfgjchoeelgbiama"
    )!
}

// MARK: - Generic

/// Icon, headline, one sentence of explanation, and an optional action.
///
/// Used wherever a list, chart or sheet legitimately has nothing to show. It is
/// deliberately not a `ContentUnavailableView`: that component sizes itself for
/// a whole screen, and most of these sit inside a card or a half-filled
/// `ScrollView`.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    /// Tighter spacing and smaller type, for use inside a card rather than as
    /// the only thing on a screen.
    var compact: Bool = false

    @ObservedObject private var paletteManager = ColorPaletteManager.shared

    private var accent: Color { paletteManager.selectedPalette.primary }

    var body: some View {
        VStack(spacing: compact ? 8 : 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: compact ? 52 : 72, height: compact ? 52 : 72)

                Image(systemName: icon)
                    .font(.system(size: compact ? 21 : 30, weight: .semibold))
                    .foregroundStyle(accent)
            }

            Text(title)
                .font(.system(size: compact ? 15 : 19, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: compact ? 13 : 14))
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(accent))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, compact ? 12 : 24)
        .padding(.vertical, compact ? 22 : 36)
    }
}

// MARK: - First run

/// What Home, Problems and Revisions show before the account has any data at
/// all.
///
/// The three steps are in the order they have to happen, because the ordering
/// is the part that is not obvious: the extension has to be installed *before*
/// the next problem is solved, or that solve is lost and the user concludes the
/// app is broken rather than that they skipped a step.
struct GettingStartedEmptyState: View {
    /// Overridden per screen so the state explains why *this* tab is empty.
    var title: String = "Nothing here yet"
    var message: String = "Traverse records what you do in the browser and reports it back here. Nothing to show until your first solve."

    @Environment(\.openURL) private var openURL
    @ObservedObject private var paletteManager = ColorPaletteManager.shared

    private var accent: Color { paletteManager.selectedPalette.primary }

    private struct Step: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let detail: String
    }

    private var steps: [Step] {
        [
            Step(
                id: 0,
                icon: "puzzlepiece.extension.fill",
                title: "Install the extension",
                detail: "It watches your LeetCode and GeeksforGeeks submissions in Chrome."
            ),
            Step(
                id: 1,
                icon: "chevron.left.forwardslash.chevron.right",
                title: "Solve a problem as usual",
                detail: "Your attempts, timing and code are captured while you work."
            ),
            Step(
                id: 2,
                icon: "arrow.triangle.2.circlepath",
                title: "Come back here",
                detail: "Your streak, revision load and analytics fill in from the first solve."
            )
        ]
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.14))
                        .frame(width: 72, height: 72)

                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(accent)
                }

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.16))
                                .frame(width: 30, height: 30)

                            Image(systemName: step.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(accent)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)

                            Text(step.detail)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)

                    if index < steps.count - 1 {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 10) {
                Button {
                    HapticManager.shared.selection()
                    openURL(TraverseLinks.extensionStore)
                } label: {
                    Text("Install the Extension")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(accent))
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.shared.selection()
                    openURL(TraverseLinks.downloads)
                } label: {
                    Text("Set-up guide")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
    }
}

#Preview("Generic") {
    VStack(spacing: 24) {
        EmptyStateView(
            icon: "tray",
            title: "No Solves Yet",
            message: "Solve a problem with the extension installed and it will show up here."
        )
        EmptyStateView(
            icon: "tag",
            title: "No mistakes detected",
            message: "Once Traverse has a few attempts to read, recurring mistakes show up here.",
            compact: true
        )
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("First run") {
    ScrollView {
        GettingStartedEmptyState()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
