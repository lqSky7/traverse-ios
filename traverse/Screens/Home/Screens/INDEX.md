# Home Detail Screens

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `ActivityDetailView.swift` | Granular activity breakdown for specific days from the heatmap | `struct ActivityDetailView: View` |
| `AllAchievementsView.swift` | Awards shelf: featured in-progress challenge card, full-width first shelf, then a two-up grid of award shelves | `struct AllAchievementsView: View`, `class AchievementsViewModel` |
| `AwardsSectionView.swift` | One award shelf opened: three-up grid of badges, plus the badge detail sheet with the tiltable medal | `struct AwardsSectionView: View`, `struct AwardDetailSheet: View` |
| `AllSolvesView.swift` | Searchable, filterable list of all recorded problem submissions | `struct AllSolvesView: View` |
| `MistakeTagsDetailView.swift` | Deep dive into frequent mistake categories and retry patterns | `struct MistakeTagsDetailView: View` |
| `RevisionLoadDetailView.swift` | Revision Load opened: All/Easy/Medium/Hard scope chips, band word and its plain-language read, 28-day trend against the baseline rule, revision-score footer | `struct RevisionLoadDetailView: View` |
| `MetricDetailView.swift` | Shared detail screen behind both Step Count tiles: D/W/M/Y picker, headline total over a bar chart with grid lines and axis labels, expandable all-time figures. Attempts additionally carries the difficulty breakdown | `struct MetricDetailView: View`, `enum MetricRange`, `enum MetricKind` |
