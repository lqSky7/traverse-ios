# Traverse Mac Feature Parity

This folder is a rewritten native macOS app, not a Catalyst build of the iOS app.

## Implemented in the Mac rewrite

- Authentication: sign in, create account, account recovery, password reset calls.
- Main macOS shell: native sidebar for Home, Revisions, Friends, and Settings.
- Custom theming: built-in iOS palettes, custom palette persistence, Coolors/SCSS/hex import, hue-based custom palette generation, dark-mode adjustment.
- Home: streak, XP, solves, submissions, achievements, freezes, recent solves.
- Home charts: difficulty, platform, submission quality, language, activity heatmap, tries distribution.
- Problems: dedicated all-solved-problems screen with search, difficulty/platform filters, and full solve detail.
- Revisions: ML-only grouped queue for paid users, stats, row detail, swipe/context-menu delete, recalibration.
- Revision charts: accuracy trend, projected load, retention risk.
- Friends: search, send friend request, received/sent requests, leaderboard, remove friend.
- Friend drill-down: profile, public stats, public solves, and achievements.
- Friend streaks: active streaks, send/accept/reject streak requests.
- Achievements: dedicated all-achievements screen and achievement detail.
- Freezes: dedicated freeze history screen, plus purchase/gift controls in Settings.
- Password reset: dedicated password-reset screen.
- Settings: profile update, password change, delete account, subscription status fetch, freeze purchase/gift controls.
- Local cache: JSON cache in Application Support restores the last known app data before network refresh.
- Fine-grained panel states: loading, empty, and failed states are shown per major panel.
- App icon: Mac asset catalog generated from the iOS Traverse glyph.

## Still missing compared with the full iOS app

- Exact iOS onboarding choreography, carousel assets, and completion animations.
- Pixel-level recreation of every iOS card, glass effect, sheet detent, and transition.
- QR camera scanner. The Mac version intentionally removes QR from Friends per latest request.
- Widget/live-activity/watch sync code. The user asked to ignore the watch app; live activities and iOS widgets do not map directly to macOS.
- Notification scheduling parity.
- The onboarding image/video assets have not yet been copied into the Mac target.
