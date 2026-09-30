# Screens

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `AccountTypeSelectionView.swift` | Account specialization picker during onboarding | `struct AccountTypeSelectionView: View` |
| `ChangePasswordView.swift` | Form to securely update password with input validation | `struct ChangePasswordView: View` |
| `DeleteAccountView.swift` | Permanent account removal confirmation with safety warnings | `struct DeleteAccountView: View` |
| `FreezeShopSheet.swift` | In-app store to purchase and manage streak freeze tokens | `struct FreezeShopSheet: View` |
| `FriendRequestsView.swift` | Incoming and outgoing friend request management | `struct FriendRequestsView: View` |
| `FriendStreakRequestsView.swift` | Collaborative streak invites and response management | `struct FriendStreakRequestsView: View` |
| `FriendsView.swift` | Social leaderboard, friend activity feeds, and streak statuses | `struct FriendsView: View` |
| `MainTabView.swift` | Root navigation controller hosting the primary app tabs | `struct MainTabView: View` |
| `NotificationSettingsView.swift` | Per-type notification preferences rendered from the server's own catalogue, so the copy and the list of configurable types live in one place. Also carries the permission card and quiet hours | `struct NotificationSettingsView: View` |
| `NotificationsView.swift` | The inbox, grouped into Today / Yesterday / This week / Earlier, with an unread dot, a coalesced-count badge, and a scroll sentinel that pages older rows in | `struct NotificationsView: View` |
| `PasswordResetView.swift` | Account recovery flow with email reset code confirmation | `struct PasswordResetView: View` |
| `ProUpgradeSheet.swift` | Pro membership sheet with feature breakdown and purchase triggers | `struct ProUpgradeSheet: View` |
| `ProfileEditView.swift` | Profile details editor for bio, avatar, and LeetCode handle | `struct ProfileEditView: View` |
| `QRCodeSheetView.swift` | Modal showing user profile QR code for easy in-person connection | `struct QRCodeSheetView: View` |
| `QRScannerView.swift` | Camera scanner to read profile QR codes and add friends | `struct QRScannerView: View` |
| `SettingsView.swift` | App preferences, themes, notifications, and developer demos | `struct SettingsView: View` |
| `ShaderDemosView.swift` | Visual showcase of custom Metal shaders and glass UI effects | `struct ShaderDemosView: View` |
| `SignInView.swift` | User authentication screen for email/password and Apple login | `struct SignInView: View` |
| `UserSearchView.swift` | Live search for finding other users by username | `struct UserSearchView: View` |
| `WelcomeScreen.swift` | Initial welcome hero screen directing to sign in or register | `struct WelcomeScreen: View` |

## Sub-Modules
- `Home/` - Home dashboard, statistics cards, and detail screens
- `Problems/` - Recent solves and mistake analysis, moved off Home so its deep solve payload is only fetched when the tab is opened
- `Revisions/` - Spaced repetition review hub and ML analytics
- `Profile/` - User profile, solve history, and achievement showcase

## Revision cleanup (2026-09-30)

The iOS app retains revision, stats, and widget support. Retention risk uses retrievability. The watchOS/macOS apps and Watch sync were removed.
