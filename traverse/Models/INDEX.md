# Models

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `AuthModels.swift` | User credential schemas, login/registration requests, and token payloads | `User`, `LoginRequest`, `LoginResponse`, `RegisterRequest`, `AuthResponse` |
| `AuthViewModel.swift` | Authentication state manager handling user sessions and token persistence | `class AuthViewModel: ObservableObject` |
| `ColorPalette.swift` | Dynamic color themes, palette presets, and tint managers | `ColorPalette`, `class ColorPaletteManager: ObservableObject` |
| `DataManager.swift` | Local persistence and caching layer for offline access to solves and stats | `class DataManager: ObservableObject` |
| `FriendStreakModels.swift` | Social streak definitions, streak requests, and freeze transactions | `FriendStreak`, `FriendStreakRequest`, `StreakFreeze` |
| `FriendsModels.swift` | Friend relationship schemas, search results, and public user profiles | `Friend`, `FriendRequest`, `PublicUserProfile` |
| `IntelligenceModels.swift` | AI revision coaching and recommendation prompt/response contracts | `IntelligenceContext`, `IntelligenceAction` |
| `OnPaperModels.swift` | Project-based interview prep models, FSRS flashcard state, and commit logs | `OnPaperProject`, `OnPaperSession`, `FSRSCard`, `OnPaperMistake` |
| `RevisionModels.swift` | Spaced repetition problem models, ML analytics, retention, and groups | `Revision`, `RevisionGroup`, `RevisionStatsResponse`, `RevisionAnalyticsResponse` |
| `StatsModels.swift` | Problem-solving metrics, difficulty breakdowns, tag summaries, and solves | `UserStats`, `SolveStats`, `SubmissionStats`, `Solve` |
