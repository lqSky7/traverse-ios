# Services Module

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `AchievementToastManager.swift` | Coordinates achievement unlock popups and celebratory toast banners | `class AchievementToastManager: ObservableObject` |
| `HapticManager.swift` | Centralized tactile feedback manager using UIKit feedback generators | `class HapticManager` |
| `IntelligenceManager.swift` | AI reasoning interface generating contextual DSA hints and advice | `class IntelligenceManager: ObservableObject` |
| `KeychainHelper.swift` | Secure storage service reading/writing JWT tokens in iOS Keychain | `class KeychainHelper` |
| `LiveActivityManager.swift` | ActivityKit coordinator managing Dynamic Island and lock screen widgets | `class LiveActivityManager` |
| `NotificationManager.swift` | Local user notification scheduler for daily streak and review reminders | `class NotificationManager` |
| `OnPaperAPIService.swift` | Networking client connecting to OnPaper project & FSRS sync backends | `class OnPaperAPIService` |
| `QRCodeGenerator.swift` | CoreImage utility rendering personal profile QR code images | `class QRCodeGenerator` |
| `SocialAuthManager.swift` | Runs the WorkOS Google/GitHub/Apple OAuth handshake in an `ASWebAuthenticationSession` | `class SocialAuthManager: NSObject`, `enum SocialAuthError` |
| `WatchSyncManager.swift` | WatchConnectivity session coordinator syncing data with Apple Watch | `class WatchSyncManager: NSObject` |
| `WidgetDataUpdater.swift` | App Group data synchronizer reloading WidgetKit timelines | `class WidgetDataUpdater` |

## Sub-Directories
- `Network/` - REST API client and domain-specific endpoint extensions
