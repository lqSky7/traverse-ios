# Network Service Module

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `NetworkService.swift` | Core network singleton managing base URL, sessions, and calendar feeds | `class NetworkService` |
| `NetworkError.swift` | Error enumerations and localized failure descriptions | `enum NetworkError: LocalizedError` |
| `NetworkService+Auth.swift` | Registration, authentication, profile updates, password resets, and account removal | `extension NetworkService` |
| `NetworkService+Stats.swift` | Personal problem-solving statistics, submission heatmaps, and achievements | `extension NetworkService` |
| `NetworkService+Users.swift` | User lookup, public profile queries, and peer solves | `extension NetworkService` |
| `NetworkService+Friends.swift` | Friend requests, social activity, friendship lists, and shared streaks | `extension NetworkService` |
| `NetworkService+Revisions.swift` | Spaced review queues, ML retention scores, attempt logging, and rescheduling | `extension NetworkService` |
| `NetworkService+Subscriptions.swift` | StoreKit receipt verification, streak freeze shop, and version sync | `extension NetworkService` |
| `NetworkService+Notifications.swift` | Notification inbox paging and unread count, read receipts, per-type preferences and quiet hours, and push-token registration | `extension NetworkService` |
| `NetworkService+Rings.swift` | Daily ring progress and the goal pair, which the server stores so a reinstall or a second device sees the same targets | `extension NetworkService` |
