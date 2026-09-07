# Profile Module

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `UserProfileView.swift` | User profile page showing stats, solve history, achievements, and social actions | `struct UserProfileView: View` |
| `UserProfileViewModel.swift` | ViewModel managing user profile data, friendship state, and streak invites | `class UserProfileViewModel: ObservableObject`, `FriendshipStatus` |

## Sub-Directories
- `Components/` - Modular subviews for profile headers, stats, solves, and badges
