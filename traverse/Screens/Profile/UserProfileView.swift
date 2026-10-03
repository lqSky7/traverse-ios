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

                    // The active-streak detail, when there is one. The action row below renders in
                    // every state, so the streak button never disappears.
                    if isFriend, viewModel.friendStreakStatus == .active,
                       let streak = viewModel.friendStreak {
                        ActiveStreakCard(streak: streak, paletteManager: paletteManager, onDelete: {
                            Task {
                                await viewModel.deleteStreak()
                            }
                        })
                        .padding(.horizontal)
                    }

                    // Streak and freeze, side by side. Everything destructive or housekeeping —
                    // remove, block, close-friend — lives in the top-right menu instead of stacking
                    // up the page.
                    if isFriend {
                        actionRow
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

    /// Gift a streak freeze, beside the streak button.
    ///
    /// Compact by design — it hugs its label instead of stretching edge to edge, so it can share a
    /// row with the streak button without either reading as the page's primary action. Its anatomy
    /// comes from `pillLabel`, the same helper the streak button is built from, so the two cannot
    /// drift apart.
    private var giftFreezeButton: some View {
        Button {
            showingGiftConfirmation = true
        } label: {
            pillLabel(
                icon: "snowflake",
                title: isGifting ? "Sending…" : "Gift Freeze",
                caption: "70 XP"
            )
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

    /// A full-width status bar, for the relationship states that replace an action outright.
    ///
    /// Distinct from `pill` on purpose: this one is the only thing in its slot, so it can afford the
    /// full width, whereas `pill` has to share a row with a second button.
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

    // MARK: - Action row

    /// The streak action and the freeze gift, side by side.
    ///
    /// They used to be two stacked rows with different shapes — a full-width "Start Streak" pill and
    /// a compact "Gift Freeze" one — so they read as two unrelated things, and the full-width pill
    /// looked like the page's primary action. Both are compact now and share one row.
    ///
    /// `ViewThatFits` picks the row when there is room and stacks them when there is not. Two glass
    /// pills plus their labels come close to the width of a narrow phone, and a row that cannot fit
    /// has to degrade rather than push the page sideways.
    private var actionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                streakButton
                giftFreezeButton
            }

            VStack(spacing: 8) {
                streakButton
                giftFreezeButton
            }
        }
        .padding(.horizontal, 12)
    }

    /// The streak button, in whichever state the relationship is in.
    ///
    /// Every state draws the same pill in the same slot; only the icon, label and tint change. The
    /// active state used to swap the button out for a card, so the control simply vanished the
    /// moment a streak existed — which is exactly when its slot most needs to stay legible.
    @ViewBuilder
    private var streakButton: some View {
        switch viewModel.friendStreakStatus {
        case .none:
            EmptyView()

        case .active:
            // A status, not an action: the card above owns ending the streak. The label is just
            // "Active" rather than "Streak Active" so the row has room for the freeze pill beside
            // it — the card above already says which streak this is.
            statusButton(
                icon: "flame.fill",
                title: "Active",
                caption: viewModel.friendStreak.map { "\($0.currentStreak)d" },
                tint: paletteManager.color(at: 0)
            )

        case .canStart:
            Button {
                Task {
                    await viewModel.sendStreakRequest()
                }
            } label: {
                pillLabel(icon: "flame", title: "Start Streak", caption: nil)
            }
            .tint(paletteManager.color(at: 0))
            .applyGlassButtonStyle(.glassProminent)

        case .requestSent:
            statusButton(
                icon: "flame.badge.checkmark",
                title: "Request Sent",
                caption: nil,
                tint: .secondary
            )

        case .requestReceived:
            statusButton(
                icon: "flame.badge.checkmark",
                title: "Request Received",
                caption: nil,
                tint: paletteManager.color(at: 0)
            )
        }
    }

    /// The shared pill anatomy: icon, label, and an optional trailing caption.
    ///
    /// Deliberately compact — it hugs its content rather than stretching, so two of them sit on one
    /// row without either reading as the page's primary action. Both the streak and the freeze
    /// button are built from this, so they cannot drift apart.
    ///
    /// Note there is no `.fixedSize()` here. It used to have one, to stop the pill stretching to fill
    /// its parent — but inside an `HStack` a button already sizes to its content, and `fixedSize`
    /// made the pill refuse to *compress* as well. Two pills wider than the row therefore could not
    /// shrink, and the row overflowed and dragged the whole page sideways with it.
    private func pillLabel(icon: String, title: String, caption: String?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            if let caption {
                Text(caption)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    /// A non-interactive pill in the same slot, for the states that report rather than act.
    ///
    /// Rendered as a *disabled button* rather than a plain capsule, and that detail matters:
    /// `applyGlassButtonStyle` is only `self.buttonStyle(.glassProminent)`, and `buttonStyle` has no
    /// effect on anything that is not a `Button`. A bare capsule therefore came out both flat — no
    /// liquid glass — and a different height from the freeze button beside it, because the button
    /// style contributes its own metrics. `.disabled(true)` keeps it inert while still picking up
    /// the glass, the same way `giftFreezeButton` looks while gifting.
    private func statusButton(icon: String, title: String, caption: String?, tint: Color) -> some View {
        Button {} label: {
            pillLabel(icon: icon, title: title, caption: caption)
        }
        .disabled(true)
        .tint(tint)
        .applyGlassButtonStyle(.glassProminent)
    }
}
