# Models

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `ActivityMetrics.swift` | Every "how much / when" figure in the app: timestamp parsing, the `activityAt` accessor, difficulty weighting, day/hour/month bucketing, revision load and its bands | `enum ActivityTimestamp`, `enum ActivityMetrics`, `enum DifficultyWeight`, `struct RevisionLoadBreakdown`, `struct RevisionLoadSnapshot`, `enum RevisionLoadBand` |
| `AuthModels.swift` | User credential schemas, login/registration requests, and token payloads | `User`, `LoginRequest`, `LoginResponse`, `RegisterRequest`, `AuthResponse` |
| `AuthViewModel.swift` | Authentication state manager handling user sessions and token persistence | `class AuthViewModel: ObservableObject` |
| `ColorPalette.swift` | Dynamic color themes, palette presets, and tint managers | `ColorPalette`, `class ColorPaletteManager: ObservableObject` |
| `DataManager.swift` | Local persistence and caching layer for offline access to solves and stats | `class DataManager: ObservableObject` |
| `FriendStreakModels.swift` | Social streak definitions, streak requests, and freeze transactions | `FriendStreak`, `FriendStreakRequest`, `StreakFreeze` |
| `FriendsModels.swift` | Friend relationship schemas, search results, and public user profiles | `Friend`, `FriendRequest`, `PublicUserProfile` |
| `IntelligenceModels.swift` | AI revision coaching and recommendation prompt/response contracts | `IntelligenceContext`, `IntelligenceAction` |
| `MedalCatalog.swift` | Slug list for the award badge renders in `Assets.xcassets/Medals`, plus the deterministic fallback pick | `enum MedalCatalog` |
| `NotificationModels.swift` | Inbox rows, the server-owned preference list (label, description, and whether a type is user-configurable), quiet hours with wrap-midnight handling, and the icon-only type enum. Flattens the free-form `data` payload through `JSONScalar` so one odd row cannot fail the whole page | `AppNotification`, `NotificationPreferences`, `NotificationTypePreference`, `QuietHours`, `NotificationType` |
| `RevisionModels.swift` | Spaced repetition problem models, ML analytics, retention, and groups | `Revision`, `RevisionGroup`, `RevisionStatsResponse`, `RevisionAnalyticsResponse` |
| `RingModels.swift` | Daily ring progress — solve and revision counts against the stored goals, both fractions clamped to 1 — plus the goal pair and its bounds | `RingProgress`, `RingGoals` |
| `StatsModels.swift` | Problem-solving metrics, difficulty breakdowns, tag summaries, and solves | `UserStats`, `SolveStats`, `SubmissionStats`, `Solve` |
