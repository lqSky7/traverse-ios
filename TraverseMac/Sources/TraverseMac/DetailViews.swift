import SwiftUI
import Charts

struct ProblemsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    @State private var search = ""
    @State private var difficulty = "All"
    @State private var platform = "All"

    private var filtered: [Solve] {
        appState.allSolves.filter { solve in
            let matchesSearch = search.isEmpty
                || solve.problem.title.localizedCaseInsensitiveContains(search)
                || solve.problem.slug.localizedCaseInsensitiveContains(search)
                || solve.problem.platform.localizedCaseInsensitiveContains(search)
                || solve.submission.language.localizedCaseInsensitiveContains(search)
            let matchesDifficulty = difficulty == "All" || solve.problem.difficulty.localizedCaseInsensitiveCompare(difficulty) == .orderedSame
            let matchesPlatform = platform == "All" || solve.problem.platform == platform
            return matchesSearch && matchesDifficulty && matchesPlatform
        }
    }

    private var platforms: [String] {
        ["All"] + Array(Set(appState.allSolves.map(\.problem.platform))).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            List(filtered) { solve in
                NavigationLink {
                    ProblemDetailView(solve: solve)
                } label: {
                    ProblemListRow(solve: solve)
                }
                .contextMenu {
                    Button("Copy Slug") {
                        #if canImport(AppKit)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(solve.problem.slug, forType: .string)
                        #elseif canImport(UIKit)
                        UIPasteboard.general.string = solve.problem.slug
                        #endif
                    }
                }
            }
            .overlay {
                if filtered.isEmpty {
                    PanelFeedback(status: appState.panelStatus(.solves), isEmpty: true, emptyTitle: "No solved problems", emptySystemImage: "checklist", emptyDescription: "All solved problems will appear here after sync.")
                }
            }
        }
        .navigationTitle("All Solved Problems")
        .task {
            if appState.allSolves.isEmpty {
                await appState.refreshAllSolves()
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            TextField("Search solved problems", text: $search)
                .textFieldStyle(.roundedBorder)
            Picker("Difficulty", selection: $difficulty) {
                ForEach(["All", "Easy", "Medium", "Hard"], id: \.self) { Text($0).tag($0) }
            }
            .frame(width: 130)
            Picker("Platform", selection: $platform) {
                ForEach(platforms, id: \.self) { Text($0).tag($0) }
            }
            .frame(width: 160)
            Spacer()
            Text("\(filtered.count) of \(appState.allSolves.count)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Button {
                Task { await appState.refreshAllSolves() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .padding(18)
        .background(.bar)
    }
}

struct ProblemListRow: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let solve: Solve

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(solve.problem.title)
                    .font(.headline)
                Text("\(solve.problem.platform) / \(solve.problem.slug)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(solve.submission.language)
                .foregroundStyle(.secondary)
            Text("\(solve.xpAwarded) XP")
                .font(.headline.monospacedDigit())
                .foregroundStyle(paletteManager.selectedPalette.primary)
            DifficultyPill(difficulty: solve.problem.difficulty)
        }
        .padding(.vertical, 5)
    }
}

struct ProblemDetailView: View {
    let solve: Solve

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ThemedCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(solve.problem.title)
                                    .font(.largeTitle.weight(.bold))
                                Text("\(solve.problem.platform) / \(solve.problem.slug)")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            DifficultyPill(difficulty: solve.problem.difficulty)
                        }
                        HStack(spacing: 20) {
                            Label("\(solve.xpAwarded) XP", systemImage: "sparkles")
                            Label(solve.submission.language, systemImage: "curlybraces")
                            Label(solve.solvedAt, systemImage: "calendar")
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                    DetailCard(title: "Submission") {
                        DetailLine("Happened at", solve.submission.happenedAt)
                        DetailLine("Number of tries", solve.submission.numberOfTries.map(String.init) ?? "Not recorded")
                        DetailLine("Time taken", solve.submission.timeTaken.map { "\($0) seconds" } ?? "Not recorded")
                    }
                    DetailCard(title: "Mistake Tags") {
                        TagCloud(tags: solve.mistakeTags ?? solve.submission.mistakeTags ?? [])
                    }
                    DetailCard(title: "AI Analysis") {
                        Text(solve.aiAnalysis ?? solve.submission.aiAnalysis ?? "No analysis recorded.")
                            .foregroundStyle(.secondary)
                    }
                    if let highlight = solve.highlight {
                        DetailCard(title: "Highlight") {
                            Text(highlight.content)
                            Text(highlight.note)
                                .foregroundStyle(.secondary)
                            TagCloud(tags: highlight.tags)
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Problem Detail")
    }
}

struct AchievementsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                ForEach(appState.achievements) { achievement in
                    NavigationLink {
                        AchievementDetailView(achievement: achievement)
                    } label: {
                        AchievementTile(achievement: achievement)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .overlay {
            if appState.achievements.isEmpty {
                PanelFeedback(status: appState.panelStatus(.achievements), isEmpty: true, emptyTitle: "No achievements", emptySystemImage: "trophy", emptyDescription: "Achievements will appear after sync.")
            }
        }
        .navigationTitle("Achievements")
    }
}

struct AchievementTile: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let achievement: AchievementDetail

    var body: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: achievement.unlocked ? "trophy.fill" : "trophy")
                    .font(.title2)
                    .foregroundStyle(achievement.unlocked ? paletteManager.color(at: 2) : .secondary)
                Text(achievement.name)
                    .font(.headline)
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(achievement.category)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(paletteManager.selectedPalette.primary.opacity(0.14), in: Capsule())
            }
        }
    }
}

struct AchievementDetailView: View {
    let achievement: AchievementDetail

    var body: some View {
        ScrollView {
            ThemedCard {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: achievement.unlocked ? "trophy.fill" : "trophy")
                        .font(.system(size: 46, weight: .bold))
                    Text(achievement.name)
                        .font(.largeTitle.weight(.bold))
                    Text(achievement.description)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    DetailLine("Key", achievement.key)
                    DetailLine("Category", achievement.category)
                    DetailLine("Status", achievement.unlocked ? "Unlocked" : "Locked")
                    DetailLine("Unlocked at", achievement.unlockedAt ?? "Not unlocked")
                }
            }
            .padding(24)
        }
        .navigationTitle("Achievement")
    }
}

struct UserProfileDetailView: View {
    @EnvironmentObject private var appState: AppState
    let username: String
    @State private var profile: UserProfile?
    @State private var stats: UserStatisticsResponse?
    @State private var solves: [UserSolve] = []
    @State private var achievements: [Achievement] = []
    @State private var error: String?
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if loading {
                    ProgressView("Loading profile")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if let error {
                    ContentUnavailableView("Could not load profile", systemImage: "person.crop.circle.badge.exclamationmark", description: Text(error))
                } else if let profile {
                    ThemedCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(profile.username)
                                    .font(.largeTitle.weight(.bold))
                                Text("\(profile.visibility.capitalized) • \(profile.timezone)")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(profile.currentStreak)")
                                    .font(.system(size: 40, weight: .black, design: .rounded))
                                Text("day streak")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    profileStats
                    userSolves
                    userAchievements
                }
            }
            .padding(24)
        }
        .navigationTitle(username)
        .task { await load() }
    }

    private var profileStats: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
            MetricCard(title: "XP", value: profile?.totalXp ?? 0, symbol: "sparkles", color: .yellow)
            MetricCard(title: "Solves", value: stats?.stats.totalSolves ?? 0, symbol: "checkmark.seal", color: .green)
            MetricCard(title: "Submissions", value: stats?.stats.totalSubmissions ?? 0, symbol: "terminal", color: .blue)
            MetricCard(title: "Streak Days", value: stats?.stats.totalStreakDays ?? 0, symbol: "flame", color: .orange)
        }
    }

    private var userSolves: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Solved Problems").font(.title3.weight(.bold))
                ForEach(solves) { solve in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(solve.problem.title).font(.headline)
                        Text("\(solve.problem.platform) • \(solve.problem.difficulty.capitalized) • \(solve.xpAwarded) XP")
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
            }
        }
    }

    private var userAchievements: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Achievements").font(.title3.weight(.bold))
                ForEach(achievements) { achievement in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(achievement.name).font(.headline)
                        Text(achievement.description)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
            }
        }
    }

    private func load() async {
        loading = true
        do {
            async let profile = APIClient.shared.userProfile(username: username)
            async let stats = APIClient.shared.userStatistics(username: username)
            async let solves = APIClient.shared.allUserSolves(username: username)
            async let achievements = APIClient.shared.userAchievements(username: username)
            self.profile = try await profile
            self.stats = try await stats
            self.solves = try await solves
            self.achievements = try await achievements.achievements
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct FreezeHistoryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ThemedCard {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Freeze History")
                                .font(.largeTitle.weight(.bold))
                            Text("Available, used, and total freeze state from Traverse.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Refresh") {
                            Task { await appState.refreshFreezes() }
                        }
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                    MetricCard(title: "Available", value: appState.freezeInfo?.availableFreezes ?? 0, symbol: "snowflake", color: Color(red: 0.31, green: 0.76, blue: 0.97))
                    MetricCard(title: "Used", value: appState.freezeInfo?.usedFreezes ?? 0, symbol: "drop.degreesign", color: .blue)
                    MetricCard(title: "Total", value: appState.freezeInfo?.totalFreezes ?? 0, symbol: "archivebox", color: .secondary)
                }
                ThemedCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Used Dates").font(.title3.weight(.bold))
                        if appState.freezeDates.isEmpty {
                            PanelFeedback(status: appState.panelStatus(.freezes), isEmpty: true, emptyTitle: "No freeze dates", emptySystemImage: "snowflake", emptyDescription: "Used freeze dates will appear here.")
                        } else {
                            ForEach(appState.freezeDates, id: \.self) { date in
                                Label(date, systemImage: "snowflake")
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Freezes")
    }
}

struct PasswordResetStandaloneView: View {
    @EnvironmentObject private var appState: AppState
    @State private var username = ""
    @State private var code = ""
    @State private var newPassword = ""

    var body: some View {
        VStack {
            ThemedCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Password Reset")
                        .font(.largeTitle.weight(.bold))
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Request Reset Code") {
                            Task {
                                do {
                                    let response = try await APIClient.shared.requestPasswordReset(username: username)
                                    appState.statusMessage = response.message
                                } catch {
                                    appState.errorMessage = error.localizedDescription
                                }
                            }
                        }
                        Spacer()
                    }
                    Divider()
                    TextField("Reset code", text: $code)
                        .textFieldStyle(.roundedBorder)
                    SecureField("New password", text: $newPassword)
                        .textFieldStyle(.roundedBorder)
                    Button("Confirm New Password") {
                        Task {
                            do {
                                try await APIClient.shared.confirmPasswordReset(username: username, code: code, newPassword: newPassword)
                                appState.statusMessage = "Password reset"
                            } catch {
                                appState.errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: 520)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Password Reset")
    }
}

struct RevisionDetailView: View {
    let revision: Revision

    var body: some View {
        ScrollView {
            ThemedCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(revision.problem.title)
                        .font(.largeTitle.weight(.bold))
                    DifficultyPill(difficulty: revision.problem.difficulty)
                    DetailLine("Platform", revision.problem.platform)
                    DetailLine("Slug", revision.problem.slug)
                    DetailLine("Revision number", "\(revision.revisionNumber)")
                    DetailLine("Scheduled for", revision.scheduledFor)
                    DetailLine("Created at", revision.createdAt)
                    DetailLine("Completed at", revision.completedAt ?? "Not completed")
                    if let solve = revision.solve {
                        DetailLine("Solve XP", "\(solve.xpAwarded)")
                        DetailLine("Solved at", solve.solvedAt)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Revision Detail")
    }
}

struct DetailCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                content
            }
        }
    }
}

struct DetailLine: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.subheadline)
    }
}

struct TagCloud: View {
    let tags: [String]

    var body: some View {
        if tags.isEmpty {
            Text("No tags recorded.")
                .foregroundStyle(.secondary)
        } else {
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.secondary.opacity(0.14), in: Capsule())
                }
            }
        }
    }
}

struct DifficultyPill: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let difficulty: String

    var body: some View {
        Text(difficulty.capitalized)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch difficulty.lowercased() {
        case "easy": paletteManager.color(at: 0)
        case "medium": paletteManager.color(at: 1)
        default: paletteManager.color(at: 2)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 400
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
