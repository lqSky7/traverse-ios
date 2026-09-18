import SwiftUI
import Glur

/// Someone's profile.
///
/// The page is deliberately shallow: an identity header, whatever action the
/// relationship allows, the statistics, and two links into the *shared* solve
/// list and Awards hub. Those two used to be an inline segmented picker with a
/// second, profile-only solve list and a second, profile-only badge grid beneath
/// it — three implementations of data the home screen already renders, on one
/// screen, with the whole page scrolling as one.
struct UserProfileView: View {
    let username: String
    @StateObject private var viewModel: UserProfileViewModel
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingGiftConfirmation = false
    @State private var isGifting = false
    @State private var giftSuccessMessage: String?
    @State private var showingRemoveConfirmation = false
    @State private var showingBlockConfirmation = false

    init(username: String) {
        self.username = username
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(username: username))
    }

    private var isFriend: Bool { viewModel.friendshipStatus == .friends }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let error = viewModel.errorMessage, viewModel.profile == nil {
                    errorState(error)
                } else if let profile = viewModel.profile {
                    ProfileHeaderView(profile: profile, statistics: viewModel.statistics)

                    // Friend streak section (only for friends)
                    if isFriend {
                        streakActionSection
                    }

                    // The single inline action. Everything destructive or
                    // housekeeping — remove, block, close-friend — lives in the
                    // top-right menu instead of stacking up the page.
                    if isFriend {
                        giftFreezeButton
                    }

                    friendActionButton

                    if let statistics = viewModel.statistics {
                        StatisticsView(statistics: statistics)
                    }

                    profileActivityLinks
                }
            }
        }
        .navigationTitle(username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarScrollMinimization()
        .toolbar {
            if showsActionsMenu {
                profileActionsMenu
            }
        }
        .task {
            await viewModel.loadProfile()
            // The streak sub-state comes from the relationship payload, so only
            // the active-streak detail still needs its own fetch.
            await viewModel.loadFriendStreakStatus()
        }
        .refreshable {
            await Task {
                await viewModel.loadProfile(force: true)
                await viewModel.loadFriendStreakStatus(force: true)
            }.value
        }
        .onAppear {
            viewModel.currentUsername = authViewModel.currentUser?.username
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .alert("Freeze Gifted!", isPresented: .constant(giftSuccessMessage != nil)) {
            Button("OK") {
                giftSuccessMessage = nil
            }
        } message: {
            if let message = giftSuccessMessage {
                Text(message)
            }
        }
        .confirmationDialog(
            "Block \(username)?",
            isPresented: $showingBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                Task { await viewModel.blockUser() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will not be able to send you friend or streak requests, and neither of you will see the other. They are not told that you blocked them.")
        }
        .confirmationDialog(
            "Remove \(username)?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Friend", role: .destructive) {
                Task { await viewModel.removeFriend() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also ends any streak you share and cancels pending requests.")
        }
    }

    // MARK: - Toolbar actions

    /// Whether the top-right menu has anything in it. An empty `Menu` still opens
    /// an empty popover, so the item is omitted rather than shown blank.
    private var showsActionsMenu: Bool {
        switch viewModel.friendshipStatus {
        case .friends:
            return true
        case .notFriends, .requestSent, .requestReceived:
            // Blocking is offered wherever you can act on someone — the case you
            // most need it in is a stranger who will not stop.
            return viewModel.relationship?.canRequest == true
        case .blocked, .currentUser:
            // A blocked profile shows its own inline "Unblock" recovery button,
            // and your own profile has nothing to manage.
            return false
        }
    }

    @ToolbarContentBuilder
    private var profileActionsMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                switch viewModel.friendshipStatus {
                case .friends:
                    let isFavorite = viewModel.relationship?.friendship?.favorite == true

                    Button {
                        Task { await viewModel.toggleFavorite() }
                    } label: {
                        Label(
                            isFavorite ? "Remove from Close Friends" : "Add to Close Friends",
                            systemImage: isFavorite ? "star.slash" : "star"
                        )
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingRemoveConfirmation = true
                    } label: {
                        Label("Remove Friend", systemImage: "person.fill.xmark")
                    }

                    Button(role: .destructive) {
                        showingBlockConfirmation = true
                    } label: {
                        Label("Block @\(username)", systemImage: "hand.raised")
                    }

                case .notFriends, .requestSent, .requestReceived:
                    Button(role: .destructive) {
                        showingBlockConfirmation = true
                    } label: {
                        Label("Block @\(username)", systemImage: "hand.raised")
                    }

                case .blocked, .currentUser:
                    EmptyView()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
            }
            .tint(paletteManager.selectedPalette.primary)
        }
    }

    // MARK: - Activity links

    /// The two things there are to look at: their solves and their awards.
    ///
    /// Each pushes the view the home screen already uses — `AllSolvesView` and
    /// the Awards hub — so there is one solve list and one award shelf in the
    /// app, and a fix in either lands here too.
    private var profileActivityLinks: some View {
        VStack(spacing: 0) {
            NavigationLink {
                ProfileSolvesView(username: username, isFriend: isFriend)
            } label: {
                activityRow(
                    icon: "checkmark.circle.fill",
                    tint: paletteManager.color(at: 0),
                    title: "Solves",
                    subtitle: "Recent problems solved"
                )
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.leading, 58)

            NavigationLink {
                AllAchievementsView(source: awardsSource)
            } label: {
                activityRow(
                    icon: "trophy.fill",
                    tint: paletteManager.color(at: 1),
                    title: "Awards",
                    subtitle: "Badges earned"
                )
            }
            .buttonStyle(.plain)
        }
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    /// Which awards endpoint to read. The friends route additionally applies the
    /// block rules, so it is preferred whenever the relationship allows it.
    private var awardsSource: AwardsSource {
        isFriend ? .friend(username) : .profile(username)
    }

    private func activityRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    // MARK: - Gift freeze

    /// The one action that stays on the page.
    ///
    /// Deliberately compact — it hugs its label instead of stretching edge to
    /// edge. As a full-width pill sitting among two other full-width pills it
    /// read as the page's primary action, pushed the statistics below the fold,
    /// and at narrow widths wrapped its own title.
    private var giftFreezeButton: some View {
        Button {
            showingGiftConfirmation = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "snowflake")
                    .font(.footnote.weight(.semibold))

                Text(isGifting ? "Sending…" : "Gift Freeze")
                    .font(.subheadline.weight(.semibold))

                Text("70 XP")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .fixedSize()
        }
        .disabled(isGifting)
        .tint(.cyan)
        .applyGlassButtonStyle(.glassProminent)
        .confirmationDialog(
            "Gift a Streak Freeze?",
            isPresented: $showingGiftConfirmation,
            titleVisibility: .visible
        ) {
            Button("Gift for 70 XP") {
                Task {
                    isGifting = true
                    let success = await viewModel.giftFreeze()
                    if success {
                        giftSuccessMessage = "Freeze gifted to \(username)!"
                        AchievementToastManager.shared.showToast(
                            name: "Freeze gifted to \(username)!",
                            category: "gift_freeze",
                            icon: "snowflake"
                        )
                    }
                    isGifting = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will cost 70 XP from your balance. \(username) can use it to protect their streak!")
        }
    }

    // MARK: - Relationship states

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(error)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    await viewModel.loadProfile()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    /// The primary action for each relationship state. The `.friends` case is
    /// empty on purpose: a friend's only on-page action is the freeze button
    /// above, and the rest moved into the top-right menu.
    @ViewBuilder
    private var friendActionButton: some View {
        switch viewModel.friendshipStatus {
        case .currentUser, .friends:
            EmptyView()

        case .notFriends:
            Button {
                Task {
                    await viewModel.sendFriendRequest()
                }
            } label: {
                Text("Send Friend Request")
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }
            .tint(paletteManager.selectedPalette.primary)
            .applyGlassButtonStyle(.glassProminent)
            .padding(.horizontal)

        case .blocked:
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                    Text("You blocked @\(username)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.secondary.opacity(0.1))
                .cornerRadius(12)

                Button {
                    Task {
                        await viewModel.unblockUser()
                    }
                } label: {
                    Text("Unblock")
                        .frame(maxWidth: .infinity)
                }
                .tint(.red)
                .applyGlassButtonStyle(.glassProminent)
            }
            .padding(.horizontal)

        case .requestSent:
            statusPill(
                icon: "clock",
                text: "Friend Request Sent",
                tint: .secondary
            )

        case .requestReceived:
            statusPill(
                icon: "envelope.badge",
                text: "Friend Request Received",
                tint: .blue
            )
        }
    }

    private func statusPill(icon: String, text: String, tint: Color) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text)
        }
        .font(.subheadline)
        .foregroundStyle(tint)
        .padding()
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var streakActionSection: some View {
        VStack(spacing: 8) {
            switch viewModel.friendStreakStatus {
            case .none:
                EmptyView()

            case .active:
                // Show active streak info with liquid glass and glow
                if let streak = viewModel.friendStreak {
                    ActiveStreakCard(streak: streak, paletteManager: paletteManager, onDelete: {
                        Task {
                            await viewModel.deleteStreak()
                        }
                    })
                    .padding(.horizontal)
                }

            case .canStart:
                Group {
                    Button {
                        Task {
                            await viewModel.sendStreakRequest()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "flame")
                            Text("Start Streak")
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                    }
                    .tint(paletteManager.color(at: 0))
                }
                .applyGlassButtonStyle(.glassProminent)
                .padding(.horizontal)

            case .requestSent:
                statusPill(
                    icon: "flame.badge.checkmark",
                    text: "Streak Request Sent",
                    tint: paletteManager.color(at: 0)
                )

            case .requestReceived:
                statusPill(
                    icon: "flame.badge.checkmark",
                    text: "Streak Request Received",
                    tint: paletteManager.color(at: 0)
                )
            }
        }
    }
}
