import Charts
import SwiftUI

struct OnPaperSpacedRevisionsBanner: View {
    let dueCount: Int
    @ObservedObject var paletteManager: ColorPaletteManager
    let onStartReview: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SPACED REPETITION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 0))
                    Text("\(dueCount) Flashcards Scheduled")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                if dueCount > 0 {
                    Button(action: onStartReview) {
                        Text("Review Now")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(paletteManager.selectedPalette.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            
            Text("Reviews are optimized mathematically via FSRS-4.5 to reinforce key patterns before decay.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Retention Health Distribution Card
struct OnPaperRetentionHealthCard: View {
    let dueCards: [OnPaperFSRSCard]
    @ObservedObject var paletteManager: ColorPaletteManager
    let onShowInfo: () -> Void
    
    private struct StabilityBucket: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
        let color: Color
    }
    
    private var buckets: [StabilityBucket] {
        let critical = dueCards.filter { $0.stability < 2.0 }.count
        let weak = dueCards.filter { $0.stability >= 2.0 && $0.stability < 7.0 }.count
        let developing = dueCards.filter { $0.stability >= 7.0 && $0.stability < 21.0 }.count
        let strong = dueCards.filter { $0.stability >= 21.0 && $0.stability < 60.0 }.count
        let mastered = dueCards.filter { $0.stability >= 60.0 }.count
        
        // Show realistic baseline defaults if no cards have been loaded yet
        let total = dueCards.count
        return [
            StabilityBucket(label: "Critical", count: total > 0 ? critical : 0, color: paletteManager.color(at: 0)),
            StabilityBucket(label: "Weak", count: total > 0 ? weak : 0, color: paletteManager.color(at: 1)),
            StabilityBucket(label: "Developing", count: total > 0 ? developing : 0, color: paletteManager.color(at: 2)),
            StabilityBucket(label: "Strong", count: total > 0 ? strong : 0, color: paletteManager.color(at: 3)),
            StabilityBucket(label: "Mastered", count: total > 0 ? mastered : 0, color: paletteManager.color(at: 4))
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(paletteManager.color(at: 4))
                Text("Retention Stability Tiers")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button(action: {
                    HapticManager.shared.selection()
                    onShowInfo()
                }) {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Tier", bucket.label),
                    y: .value("Count", bucket.count)
                )
                .foregroundStyle(bucket.color.gradient)
                .cornerRadius(3)
                .annotation(position: .top) {
                    if bucket.count > 0 {
                        Text("\(bucket.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 110)
            .chartXAxis {
                AxisMarks(values: buckets.map { $0.label }) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Connected Repositories Glance Card
struct OnPaperConnectedReposGlanceCard: View {
    let projects: [OnPaperProject]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(paletteManager.color(at: 1))
                Text("Connected Repositories")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(projects.count) Active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            if projects.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Repositories Synchronized")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text("Initialize your project with 'onpaper init' to sync curriculum units and learning sessions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(projects) { project in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Languages: \(project.primaryLanguages.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(project.curriculumStatus.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(paletteManager.selectedPalette.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(paletteManager.selectedPalette.primary.opacity(0.15), in: Capsule())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Cloud Architecture & Sync Card
struct OnPaperCloudStatusCard: View {
    let isAuthenticated: Bool
    let lastSync: Date?
    let region: String
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cloud.fill")
                    .font(.caption)
                    .foregroundStyle(isAuthenticated ? .green : paletteManager.color(at: 0))
                Text("CLOUD ARCHITECTURE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isAuthenticated ? "Authenticated (\(region))" : "Connected (\(region))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isAuthenticated ? .green : .secondary)
            }
            
            if let lastSync = lastSync {
                Text("Last synchronized: \(lastSync.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Project Card
