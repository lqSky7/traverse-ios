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
            case "globe": return "globe"
            case "code", "curlybraces": return "curlybraces"
            default: break
            }
        }
        
        if toast.count > 1 || toast.category.lowercased() == "multi" {
            return "sparkles"
        }
        
        switch toast.category.lowercased() {
        case "friend_request": return "person.badge.plus.fill"
        case "streak_request": return "flame.circle.fill"
        case "gift_freeze", "freeze": return "snowflake"
        case "solve", "solves": return "checkmark.seal.fill"
        case "streak": return "flame.fill"
        case "xp": return "star.fill"
        case "social": return "person.2.fill"
        case "language": return "curlybraces"
        case "revision", "revisions", "ml": return "brain.head.profile"
        case "fun": return "party.popper.fill"
        default: return "trophy.fill"
        }
    }
    
    private var categoryColor: Color {
        if toast.count > 1 || toast.category.lowercased() == "multi" {
            return paletteManager.selectedPalette.primary
        }
        switch toast.category.lowercased() {
        case "friend_request": return paletteManager.color(at: 2)
        case "streak_request": return paletteManager.color(at: 0)
        case "gift_freeze", "freeze": return paletteManager.color(at: 1)
        case "solve", "solves": return paletteManager.color(at: 1)
        case "streak": return paletteManager.color(at: 0)
        case "xp": return paletteManager.color(at: 3)
        case "social": return paletteManager.color(at: 2)
        case "language": return paletteManager.color(at: 1)
        case "revision", "revisions", "ml": return paletteManager.color(at: 4)
        case "fun": return paletteManager.color(at: 0)
        default: return paletteManager.color(at: 3)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Clean Icon inside flat circular background (NO blur or glow around icon)
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.18))
                    .frame(width: 36, height: 36)
                
                Image(systemName: categoryIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(categoryColor)
            }
            
            // Title text ONLY (e.g. "3 achievements unlocked" or "Hello, World!")
            Text(toast.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            // Dismiss Button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .modifier(LiquidGlassToastModifier())
        .overlay(
            Capsule()
                .stroke(categoryColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 20)
    }
}

// MARK: - Liquid Glass Toast Modifier (.clear .interactive)
struct LiquidGlassToastModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.clear.interactive(), in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
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
