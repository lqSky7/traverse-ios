# Revisions Module

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `RevisionsView.swift` | Primary revisions view managing spaced review queues, filters, and study state | `struct RevisionsView: View` |

## Sub-Directories
- `Components/` - Spaced repetition problem cards and analytics widgets
- `Sheets/` - Review limit, ML scheduling info, and topic detail sheets
- `Helpers/` - Interactive Easter egg accelerometer monitors

## Revision cleanup (2026-09-30)

The iOS app retains revision, stats, and widget support. Retention risk uses retrievability. The watchOS/macOS apps and Watch sync were removed.
