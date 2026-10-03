# Home Components

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `HomeScoreCards.swift` | Streak card: a flat `systemGray6` tile carrying the two activity rings, a chroma-swept streak number, and a seven-day week strip whose dots walk the brand chroma band. Opens the goal sheet when tapped. The old lighting-sun shader background was removed — the Metal function itself survives, used by `LightingSimDemoView` | `StreakCard`, `StreakDay`, `StreakDayState`, `WeekStrip` |
| `HomeLoadCard.swift` | Revision Load tile in the shape of Apple Fitness' Training Load card: gauge, band word, 7-day vs 28-day comparison, revision score footer | `RevisionLoadCard`, `RevisionLoadGauge` |
| `HomeStepMetricCards.swift` | Time and attempt analysis as Step Count style tiles (title, chevron, Today, hero number, hourly bar strip) plus shared number formatting | `TimeAnalysisCard`, `AttemptsAnalysisCard`, `StepMetricCard`, `MetricFormat` |
| `HomeStatsCards.swift` | Main solve statistics summary and the shared error view | `MainStatsCard`, `StatItem`, `ErrorView` |
| `HomeChartCards.swift` | Progress rows for the difficulty and platform breakdowns (the standalone Difficulty card is gone; `DifficultyProgressRow` now renders inside the attempts detail screen) | `DifficultyProgressRow`, `PlatformChartCard`, `PlatformProgressRow` |
| `HomeInsightsCards.swift` | Award card and the weekly solves-vs-revisions activity chart | `AchievementStatsCard`, `ProductivityInsightsCard` |
| `HomeHoursCard.swift` | Peak / fastest hour summary and 24-bar histogram, bucketed on last activity time | `BestSolvingHoursCard` |
| `HomeSolvesCards.swift` | Submission statistics, the full-width activity heatmap, and the shared solve row used by every solve list | `SubmissionStatsCard`, `SolveHeatmapCard`, `SubmissionBreakdownCard`, `SolveRow` |
| `MedalView.swift` | Award badge renderer with press-and-drag 3D tilt, specular sweep and locked treatment; plus the progress bar and award caption formatting | `MedalView`, `MedalProgressBar`, `AwardFormat` |

## Revision cleanup (2026-09-30)

The iOS app retains revision, stats, and widget support. Retention risk uses retrievability. The watchOS/macOS apps and Watch sync were removed.
