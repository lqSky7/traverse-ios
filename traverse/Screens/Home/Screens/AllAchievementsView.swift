import Combine
import SwiftUI

struct AllAchievementsView: View {
    @StateObject private var viewModel = AchievementsViewModel()
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @State private var filterMode: AchievementFilter = .all
    
    enum AchievementFilter: String, CaseIterable {
        case all = "All"
        case unlocked = "Unlocked"
        case locked = "Locked"
    }
    
    private var filteredAchievements: [AchievementDetail]? {
        guard let achievements = viewModel.achievements else { return nil }
        
        switch filterMode {
        case .all:
            return achievements
        case .unlocked:
            return achievements.filter { $0.unlocked }
        case .locked:
            return achievements.filter { !$0.unlocked }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 100)
                    } else if let error = viewModel.errorMessage {
                        ErrorView(message: error, retry: {
                            Task {
                                await viewModel.loadAchievements()
                            }
                        })
                    } else if let achievements = filteredAchievements {
                        // Spacer for sticky card
                        Color.clear
                            .frame(height: 130)
                        
                        // Categories with expandable achievements
                        CategoriesSection(achievements: achievements, paletteManager: paletteManager)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
            }
            
            // Sticky Summary Card
            if let achievements = viewModel.achievements {
                VStack {
                    SummaryCard(
                        achievements: achievements,
                        paletteManager: paletteManager
                    )
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
        }
        .navigationTitle("All Achievements")
        .navigationBarTitleDisplayMode(.large)
        .toolbarScrollMinimization()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(AchievementFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            filterMode = filter
                        }) {
                            HStack {
                                Text(filter.rawValue)
                                if filterMode == filter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onAppear {
            if viewModel.achievements == nil {
                Task {
                    await viewModel.loadAchievements()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let achievements: [AchievementDetail]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var unlockedCount: Int {
        achievements.filter { $0.unlocked }.count
    }
    
    private var totalCount: Int {
        achievements.count
    }
    
    private var progressPercentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(unlockedCount) / Double(totalCount)) * 100)
    }
    
    private var remainingCount: Int {
        totalCount - unlockedCount
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress with vertical separators
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(totalCount)")
                        .font(.title)
                        .bold()
                        .foregroundStyle(paletteManager.color(at: 0))
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // Vertical separator
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 40)
                
                VStack(spacing: 4) {
                    Text("\(progressPercentage)%")
                        .font(.title)
                        .bold()
                        .foregroundStyle(paletteManager.color(at: 3))
                    Text("Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // Vertical separator
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 40)
                
                VStack(spacing: 4) {
                    Text("\(remainingCount)")
                        .font(.title)
                        .bold()
                        .foregroundStyle(.gray)
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Mesh Gradient Background
struct MeshGradientBackground: View {
    @ObservedObject var paletteManager: ColorPaletteManager
    let phase: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                // Multiple gradient layers for mesh effect
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    paletteManager.color(at: index).opacity(0.3),
                                    paletteManager.color(at: index).opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(
                            x: geometry.size.width * (0.3 + CGFloat(index) * 0.2) * (1 + phase * 0.3) - 200,
                            y: geometry.size.height * (0.2 + CGFloat(index) * 0.3) * (1 - phase * 0.2) - 200
                        )
                        .blur(radius: 60)
                }
                
                // Additional moving gradient layer
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                paletteManager.color(at: 4).opacity(0.25),
                                paletteManager.color(at: 3).opacity(0.12),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 350
                        )
                    )
                    .frame(width: 500, height: 500)
                    .offset(
                        x: geometry.size.width * 0.7 * (1 - phase * 0.4) - 250,
                        y: geometry.size.height * 0.6 * (1 + phase * 0.3) - 250
                    )
                    .blur(radius: 80)
            }
        }
    }
}

// MARK: - Categories Section
struct CategoriesSection: View {
    let achievements: [AchievementDetail]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var groupedAchievements: [String: [AchievementDetail]] {
        Dictionary(grouping: achievements) { $0.category }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements by Category")
                .font(.headline)
            
            ForEach(groupedAchievements.sorted(by: { $0.key < $1.key }), id: \.key) { category, categoryAchievements in
                AchievementCategoryCard(
                    category: category,
                    achievements: categoryAchievements,
                    paletteManager: paletteManager
                )
            }
        }
    }
}

// MARK: - Achievement Category Card
struct AchievementCategoryCard: View {
    let category: String
    let achievements: [AchievementDetail]
    @ObservedObject var paletteManager: ColorPaletteManager
    @State private var isExpanded = false
    
    private var unlockedCount: Int {
        achievements.filter { $0.unlocked }.count
    }
    
    private var categoryIcon: String {
        switch category.lowercased() {
        case "solve", "solves": return "checkmark.seal.fill"
        case "streak": return "flame.fill"
        case "social": return "person.2.fill"
        case "revision", "revisions", "ml": return "brain.head.profile"
        default: return "trophy.fill"
        }
    }
    
    private var categoryColor: Color {
        switch category.lowercased() {
        case "solve", "solves": return paletteManager.color(at: 1)
        case "streak": return paletteManager.color(at: 0)
        case "social": return paletteManager.color(at: 2)
        case "revision", "revisions", "ml": return paletteManager.color(at: 4)
        default: return paletteManager.color(at: 3)
        }
    }
    
    private var sortedAchievements: [AchievementDetail] {
        achievements.sorted { ($0.unlocked && !$1.unlocked) || ($0.unlocked == $1.unlocked && $0.name < $1.name) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category Header Button (matching SolveRow expansion toggle logic)
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: categoryIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(categoryColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.capitalized)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("\(unlockedCount) of \(achievements.count) unlocked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expandable Achievements List
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.gray.opacity(0.25))
                    
                    let sorted = sortedAchievements
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, achievement in
                        AchievementRow(achievement: achievement, paletteManager: paletteManager)
                        
                        if index < sorted.count - 1 {
                            Divider()
                                .background(Color.gray.opacity(0.25))
                                .padding(.leading, 68)
                        }
                    }
                }
            }
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Achievement Row
struct AchievementRow: View {
    let achievement: AchievementDetail
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var categoryIcon: String {
        if let icon = achievement.icon, !icon.isEmpty {
            if UIImage(systemName: icon) != nil {
                return icon
            }
            switch icon.lowercased() {
            case "trophy": return "trophy.fill"
            case "flame", "fire": return "flame.fill"
            case "star": return "star.fill"
            case "bolt", "zap": return "bolt.fill"
            case "brain": return "brain.head.profile"
            case "crown": return "crown.fill"
            case "target": return "target"
            case "seal", "badge": return "checkmark.seal.fill"
            case "chart": return "chart.line.uptrend.xyaxis"
            case "sparkles": return "sparkles"
            case "award": return "award.fill"
            default: break
            }
        }
        switch achievement.category.lowercased() {
        case "solve", "solves": return "checkmark.seal.fill"
        case "streak": return "flame.fill"
        case "social": return "person.2.fill"
        case "revision", "revisions", "ml": return "brain.head.profile"
        default: return "trophy.fill"
        }
    }
    
    private var categoryColor: Color {
        guard achievement.unlocked else { return Color.gray }
        switch achievement.category.lowercased() {
        case "solve", "solves": return paletteManager.color(at: 1)
        case "streak": return paletteManager.color(at: 0)
        case "social": return paletteManager.color(at: 2)
        case "revision", "revisions", "ml": return paletteManager.color(at: 4)
        default: return paletteManager.color(at: 3)
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Clean Achievement Badge Icon (no blur or glow)
            ZStack {
                if achievement.unlocked {
                    Circle()
                        .fill(categoryColor.opacity(0.18))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: categoryIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(categoryColor)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(achievement.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(achievement.unlocked ? .white : .gray)
                    
                    if achievement.unlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                if achievement.unlocked, let unlockedAt = achievement.unlockedAt {
                    Text("Unlocked \(formatDate(unlockedAt))")
                        .font(.caption2)
                        .foregroundStyle(categoryColor.opacity(0.9))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .opacity(achievement.unlocked ? 1.0 : 0.65)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return "recently"
        }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }
}

// MARK: - Achievements View Model
class AchievementsViewModel: ObservableObject {
    @Published var achievements: [AchievementDetail]?
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
                AchievementToastManager.shared.checkNewAchievements(response.achievements)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - Submission Stats Card
