# Problems Screen Module

The tab that owns the deep solve payload. Home asks for a small page (`HomeViewModel.homeSolveLimit`,
60) and refreshes cheaply; this screen asks for a long one (200) and only when it is actually opened.
The move is what makes Home refresh fast — the rows carry AI analysis text, mistake tags and full
attempt history, which is the heaviest thing the API returns, and it used to be pulled on every
pull-to-refresh to feed two cards.

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `ProblemsView.swift` | Tab root: mistake analysis and recent solves, with loading, error and getting-started states | `struct ProblemsView: View`, `struct ProblemsTab: View` |
| `ProblemsViewModel.swift` | Owns the deep fetch. Seeds from the shared persisted cache so the tab paints instantly, then merges the network result into that cache rather than replacing it | `class ProblemsViewModel: ObservableObject` |

## Sub-Directories
- `Components/` - The two cards the tab renders
