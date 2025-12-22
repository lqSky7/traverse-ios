import CoreHaptics
import Combine
import UIKit

class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    var engine: CHHapticEngine?
    
    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Failed to start haptic engine: \(error)")
        }
    }
    
    func playSoftRisingFeedback() {
        guard let engine = engine else { return }
        
        // Continuous haptic event (1 second)
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                // Low sharpness = "Soft", "Round", "Dull" feel
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
                // Moderate intensity so it's felt but not aggressive
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4)
            ],
            relativeTime: 0,
            duration: 1.0
        )
        
        // Intensity curve: Gentle swell
        let intensityCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.0, value: 0.1),    // Start barely perceptible
                .init(relativeTime: 0.5, value: 0.5),    // Swell to medium
                .init(relativeTime: 1.0, value: 0.1)     // Fade out
            ],
            relativeTime: 0
        )
        
        // Sharpness curve: Keep it low to maintain softness
        let sharpnessCurve = CHHapticParameterCurve(
            parameterID: .hapticSharpnessControl,
            controlPoints: [
                .init(relativeTime: 0.0, value: 0.0),    // Very dull start
                .init(relativeTime: 0.5, value: 0.2),    // Slightly more definition at peak
                .init(relativeTime: 1.0, value: 0.0)     // Fade to dull
            ],
            relativeTime: 0
        )
        
        do {
            let pattern = try CHHapticPattern(
                events: [event],
                parameterCurves: [intensityCurve, sharpnessCurve]
            )
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }
    
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}
