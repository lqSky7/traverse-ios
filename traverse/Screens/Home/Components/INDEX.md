# Home Components

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `HomeScoreCards.swift` | Streak card plus the animated lighting-sun shader background it sits on | `StreakCard`, `LightingSunBackground`, `AnimatableLightingSun` |
| `HomeLoadCard.swift` | Revision Load tile in the shape of Apple Fitness' Training Load card: gauge, band word, 7-day vs 28-day comparison, revision score footer | `RevisionLoadCard`, `RevisionLoadGauge` |
| `HomeStepMetricCards.swift` | Time and attempt analysis as Step Count style tiles (title, chevron, Today, hero number, hourly bar strip) plus shared number formatting | `TimeAnalysisCard`, `AttemptsAnalysisCard`, `StepMetricCard`, `MetricFormat` |
| `HomeStatsCards.swift` | Main solve statistics summary and the shared error view | `MainStatsCard`, `StatItem`, `ErrorView` |
| `HomeChartCards.swift` | Progress rows for the difficulty and platform breakdowns (the standalone Difficulty card is gone; `DifficultyProgressRow` now renders inside the attempts detail screen) | `DifficultyProgressRow`, `PlatformChartCard`, `PlatformProgressRow` |
| `HomeInsightsCards.swift` | Award card and the weekly solves-vs-revisions activity chart | `AchievementStatsCard`, `ProductivityInsightsCard` |
| `HomeHoursCard.swift` | Peak / fastest hour summary and 24-bar histogram, bucketed on last activity time | `BestSolvingHoursCard` |
| `HomeSolvesCards.swift` | Submission statistics, the full-width activity heatmap, and the shared solve row used by every solve list | `SubmissionStatsCard`, `SolveHeatmapCard`, `SubmissionBreakdownCard`, `SolveRow` |
| `MedalView.swift` | Award badge renderer with press-and-drag 3D tilt, specular sweep and locked treatment; plus the progress bar and award caption formatting | `MedalView`, `MedalProgressBar`, `AwardFormat` |
