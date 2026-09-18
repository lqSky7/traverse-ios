import Combine
import SwiftUI

/// The Awards shelf — Apple Fitness' award page, rebuilt for Traverse.
///
/// Layout mirrors the Fitness app: an in-progress challenge card leads, the first shelf
/// gets a full-width hero card, and the remaining shelves sit in a two-up grid. A shelf
/// with nothing on it yet spans the full width so its empty-state copy has room to breathe.
struct AllAchievementsView: View {
    @StateObject private var viewModel = AchievementsViewModel()
    @ObservedObject var paletteManager = ColorPaletteManager.shared

    private let cardBackground = Color(white: 0.11)

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isLoading && viewModel.sections.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 120)
                    } else if let error = viewModel.errorMessage, viewModel.sections.isEmpty {
                        ErrorView(message: error, retry: {
                            Task { await viewModel.loadAchievements() }
                        })
                    } else {
                        if let featured = viewModel.featured {
                            NavigationLink(
                                destination: destination(for: featured)
                            ) {
                                FeaturedAwardCard(
                                    award: featured,
                                    cardBackground: cardBackground,
                                    paletteManager: paletteManager
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(Array(shelfRows.enumerated()), id: \.offset) { _, row in
                            if row.count == 1 {
                                shelfLink(row[0])
                            } else {
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(row) { section in
                                        shelfLink(section)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Awards")
        .navigationBarTitleDisplayMode(.large)
        .toolbarScrollMinimization()
        .onAppear {
            if viewModel.sections.isEmpty {
                Task { await viewModel.loadAchievements() }
            }
        }
        .refreshable {
            await viewModel.loadAchievements()
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Layout

    /// Rows of shelves: full-width heroes, and pairs for the two-up grid.
    private var shelfRows: [[AwardSection]] {
        var rows: [[AwardSection]] = []
        var pending: AwardSection?

        for (index, section) in viewModel.sections.enumerated() {
            // The first shelf leads the page; an empty shelf needs the width for its copy.
            let wide = index == 0 || section.total == 0

            if wide {
                if let held = pending {
                    rows.append([held])
                    pending = nil
                }
                rows.append([section])
            } else if let held = pending {
                rows.append([held, section])
                pending = nil
            } else {
                pending = section
            }
        }

        if let held = pending { rows.append([held]) }
        return rows
    }

    private func shelfLink(_ section: AwardSection) -> some View {
        NavigationLink(destination: AwardsSectionView(section: section)) {
            AwardShelfCard(section: section, cardBackground: cardBackground)
        }
        .buttonStyle(.plain)
    }

    private func destination(for award: AchievementDetail) -> some View {
        if let section = viewModel.sections.first(where: { $0.id == award.section }) {
            return AnyView(AwardsSectionView(section: section))
        }
        return AnyView(AwardsSectionView(section: AwardSection(
            id: award.section ?? "workouts",
            title: "Awards",
            subtitle: "",
            emptyCopy: "",
            unlocked: 0,
            total: 1,
            achievements: [award]
        )))
    }
}

// MARK: - Featured challenge card

/// The wide card that leads the page: the challenge currently in flight, shown with its
/// badge drained back so it reads as "not yet earned".
private struct FeaturedAwardCard: View {
    let award: AchievementDetail
    let cardBackground: Color
    @ObservedObject var paletteManager: ColorPaletteManager

    var body: some View {
        HStack(spacing: 16) {
            MedalView(
                medal: award.medalAsset,
                unlocked: award.unlocked,
                size: 64,
                interactive: false,
                showsShadow: false
            )
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 3) {
                Text(award.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(award.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let progress = award.progress, !award.unlocked {
                    Text(progress.caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Shelf card

/// One award shelf on the hub. Leads with the newest badge the user earned on that shelf.
private struct AwardShelfCard: View {
    let section: AwardSection
    let cardBackground: Color

    private var isEmpty: Bool { section.total == 0 || section.hero == nil }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(section.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }

            if isEmpty {
                emptyState
            } else if let hero = section.hero {
                MedalView(
                    medal: hero.medalAsset,
                    unlocked: hero.unlocked,
                    size: 116,
                    interactive: false
                )
                .frame(height: 116)

                VStack(spacing: 4) {
                    Text(hero.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(hero.unlocked ? .white : Color.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(AwardFormat.caption(for: hero))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                badgeStack
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// The little row of recent badges under the hero — Apple's "and these too" flourish.
    private var badgeStack: some View {
        HStack(spacing: -12) {
            ForEach(section.stack) { award in
                MedalView(
                    medal: award.medalAsset,
                    unlocked: award.unlocked,
                    size: 30,
                    interactive: false,
                    showsShadow: false
                )
                .frame(width: 30, height: 30)
            }
        }
        .frame(height: 30)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                // A drained silhouette standing in for the shelf's badge.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 3)
                    .frame(width: 84, height: 92)
                Image(systemName: "trophy")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.18))
            }
            .frame(height: 116)

            Text(section.emptyCopy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - View Model

class AchievementsViewModel: ObservableObject {
    @Published var achievements: [AchievementDetail]?
    @Published var sections: [AwardSection] = []
    @Published var featured: AchievementDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadAchievements() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let response = try await NetworkService.shared.getAllAchievements()
            await MainActor.run {
                self.achievements = response.achievements
                self.sections = response.sections ?? Self.fallbackSections(response.achievements)
                self.featured = response.featured ?? Self.fallbackFeatured(response.achievements)
                AchievementToastManager.shared.checkNewAchievements(response.achievements)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    // MARK: Fallbacks for servers that predate the award shelves

    private static let fallbackTitles: [String: (String, String, String)] = [
        "rings": ("Close Your Rings", "Awards for keeping your streak alive.", "Keep a streak going to earn awards."),
        "monthly": ("Monthly Challenges", "Awards for the challenges set each month.", "Solve problems this month to earn the award."),
        "workouts": ("Workouts", "Awards for your training volume and records.", "Log some solving workouts to earn awards."),
        "competitions": ("Competitions", "Awards for competing with friends.", "Complete competitions to earn awards."),
        "limited": ("Limited Edition", "Limited edition awards.", "Special awards appear here when available."),
    ]
    private static let fallbackOrder = ["rings", "monthly", "workouts", "competitions", "limited"]

    static func fallbackSections(_ achievements: [AchievementDetail]) -> [AwardSection] {
        let grouped = Dictionary(grouping: achievements) { $0.section ?? "workouts" }
        return fallbackOrder.compactMap { id in
            guard let items = grouped[id], let meta = fallbackTitles[id] else { return nil }
            return AwardSection(
                id: id,
                title: meta.0,
                subtitle: meta.1,
                emptyCopy: meta.2,
                unlocked: items.filter { $0.unlocked }.count,
                total: items.count,
                achievements: items.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
            )
        }
    }

    static func fallbackFeatured(_ achievements: [AchievementDetail]) -> AchievementDetail? {
        achievements
            .filter { $0.unlocked }
            .sorted { ($0.unlockedAt ?? "") > ($1.unlockedAt ?? "") }
            .first
            ?? achievements.first
    }
}
