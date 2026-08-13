import SwiftUI

struct AchievementToastView: View {
    let toast: AchievementToastItem
    let onDismiss: () -> Void
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    
    private var categoryIcon: String {
        if let icon = toast.icon, !icon.isEmpty {
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
        switch toast.category.lowercased() {
        case "solve", "solves": return "checkmark.seal.fill"
        case "streak": return "flame.fill"
        case "social": return "person.2.fill"
        case "revision", "revisions", "ml": return "brain.head.profile"
        default: return "trophy.fill"
        }
    }
    
    private var categoryColor: Color {
        switch toast.category.lowercased() {
        case "solve", "solves": return paletteManager.color(at: 1)
        case "streak": return paletteManager.color(at: 0)
        case "social": return paletteManager.color(at: 2)
        case "revision", "revisions", "ml": return paletteManager.color(at: 4)
        default: return paletteManager.color(at: 3)
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Glowing Achievement Badge Icon
            ZStack {
                Circle()
                    .stroke(categoryColor.opacity(0.4), lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .blur(radius: 2)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [categoryColor.opacity(0.35), categoryColor.opacity(0.12)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 22
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: categoryIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(categoryColor)
                    .shadow(color: categoryColor.opacity(0.6), radius: 3)
            }
            
            // Text Content (Achievement Name & Description)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("ACHIEVEMENT UNLOCKED")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(categoryColor)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(categoryColor)
                }
                
                Text(toast.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(toast.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 4)
            
            // Dismiss Button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .modifier(LiquidGlassToastModifier())
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(categoryColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
    }
}

// MARK: - Liquid Glass Toast Modifier (.clear .interactive)
struct LiquidGlassToastModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - Toast Overlay Presenter Container
struct AchievementToastOverlayContainer: View {
    @ObservedObject var toastManager = AchievementToastManager.shared
    
    var body: some View {
        VStack {
            if let toast = toastManager.currentToast {
                AchievementToastView(toast: toast, onDismiss: {
                    toastManager.dismissCurrentToast()
                })
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toastManager.currentToast)
        .ignoresSafeArea(.keyboard, edges: .all)
    }
}
