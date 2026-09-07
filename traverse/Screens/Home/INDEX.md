# Home Screen Module

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `HomeView.swift` | Main dashboard view assembling streak, stats, charts, and activity | `struct HomeView: View` |
| `HomeViewModel.swift` | ObservableObject fetching and coordinating all home dashboard data | `class HomeViewModel: ObservableObject` |

## Sub-Directories
- `Components/` - Reusable dashboard widgets and cards
- `Screens/` - Secondary detail screens pushed from Home cards
- `Sheets/` - Modal information and explanation sheets
