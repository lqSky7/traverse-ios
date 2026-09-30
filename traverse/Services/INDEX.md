# Services Module

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `AchievementToastManager.swift` | Coordinates achievement unlock popups and celebratory toast banners | `class AchievementToastManager: ObservableObject` |
| `HapticManager.swift` | Centralized tactile feedback manager using UIKit feedback generators | `class HapticManager` |
| `IntelligenceManager.swift` | AI reasoning interface generating contextual DSA hints and advice | `class IntelligenceManager: ObservableObject` |
| `KeychainHelper.swift` | Secure storage service reading/writing JWT tokens in iOS Keychain | `class KeychainHelper` |
| `LiveActivityManager.swift` | ActivityKit coordinator managing Dynamic Island and lock screen widgets | `class LiveActivityManager` |
| `NotificationInboxManager.swift` | Server notification inbox: paged keyset loading, optimistic read/unread with rollback, and the app-icon badge count | `class NotificationInboxManager: ObservableObject` |
| `NotificationManager.swift` | Local user notification scheduler for daily streak and review reminders, and the delegate for remote pushes — it tells server pushes apart from local reminders by the `notificationId` key, refreshes the badge from the server on foreground, and routes taps | `class NotificationManager` |
| `NotificationRouter.swift` | Maps a notification's `link` (falling back to its `type`) onto a tab destination, and formats relative timestamps and day buckets for the inbox | `enum NotificationRouter`, `NotificationRouter.Destination` |
| `PushRegistrationService.swift` | Requests notification authorization, hex-encodes the APNs device token, uploads it with the right sandbox flag, and unregisters on sign-out | `class PushRegistrationService` |
| `QRCodeGenerator.swift` | CoreImage utility rendering personal profile QR code images | `class QRCodeGenerator` |
| `RingsManager.swift` | Owns the two daily rings: seeds the first frame from a `UserDefaults` cache (rejecting a stale one from a previous day), refreshes after activity, and saves goal changes optimistically | `class RingsManager: ObservableObject` |
| `WidgetDataUpdater.swift` | App Group data synchronizer reloading WidgetKit timelines | `class WidgetDataUpdater` |

## Sub-Directories
- `Network/` - REST API client and domain-specific endpoint extensions

## Revision cleanup (2026-09-30)

The iOS app retains revision, stats, and widget support. Retention risk uses retrievability. The watchOS/macOS apps and Watch sync were removed.
