import SwiftUI
import UserNotifications

/// Notification settings: per-type switches, quiet hours, and the system
/// permission state.
///
/// The per-type list is rendered from the server's catalog rather than a
/// client-side array. That is deliberate: the server decides which types exist
/// and which are user-configurable, so a build that hard-coded its own list would
/// offer switches the API silently ignores, and would keep offering a type after
/// the server stopped sending it.
///
/// Each type carries two independent switches and they mean different things:
/// the in-app switch decides whether the event is recorded in the inbox at all,
/// and the push switch decides whether it also interrupts. They are shown
/// together because the useful question is "do I want this at all, and if so how"
/// — not two separate screens.
struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var paletteManager = ColorPaletteManager.shared

    @State private var preferences: NotificationPreferences = .empty
    @State private var pushConfigured = false
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var savingType: String?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError {
                    errorState(loadError)
                } else {
                    content
                }
            }
            .background(Color.black)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 22) {
                permissionSection

                if !pushConfigured {
                    pushUnavailableNote
                }

                if let saveError {
                    saveErrorBanner(saveError)
                }

                typeSection

                quietHoursSection
            }
            .padding(20)
        }
    }

    // MARK: - Permission

    @ViewBuilder
    private var permissionSection: some View {
        switch authorizationStatus {
        case .denied:
            // The only state the app can act on. Once the user has declined,
            // iOS will not prompt again, so the only honest thing to offer is a
            // route into Settings.
            settingsCard(
                icon: "bell.slash.fill",
                tint: .orange,
                title: "Notifications are off",
                message: "iOS is blocking Traverse notifications. The inbox still works, but nothing will reach your lock screen.",
                actionTitle: "Open Settings"
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }

        case .notDetermined:
            settingsCard(
                icon: "bell.badge.fill",
                tint: paletteManager.color(at: 0),
                title: "Turn on notifications",
                message: "Get told when a friend request lands, an award unlocks, or you are one solve from closing your rings.",
                actionTitle: "Allow"
            ) {
                Task { await requestPermission() }
            }

        default:
            EmptyView()
        }
    }

    private func settingsCard(
        icon: String,
        tint: Color,
        title: String,
        message: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Text(actionTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(tint))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.systemGray6).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var pushUnavailableNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)

            Text("Push delivery is not switched on for this build yet. Your inbox, badge and these settings all work — banners will start arriving once it is enabled.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(UIColor.systemGray6).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Types

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("What to notify me about")

            VStack(spacing: 0) {
                ForEach(Array(preferences.types.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.leading, 52)
                    }

                    typeRow(entry)
                }
            }
            .background(Color(UIColor.systemGray6).opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func typeRow(_ entry: NotificationTypePreference) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: entry.icon)
                .font(.system(size: 16))
                .foregroundStyle(paletteManager.color(at: 0))
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)

                Text(entry.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            if savingType == entry.type {
                ProgressView().controlSize(.mini)
            }

            // Two switches, labelled. An unlabelled pair would be a coin flip.
            VStack(alignment: .trailing, spacing: 6) {
                toggleRow(
                    label: "Push",
                    isOn: entry.push,
                    enabled: entry.userConfigurable
                ) { newValue in
                    Task { await updatePush(entry, to: newValue) }
                }

                toggleRow(
                    label: "In-app",
                    isOn: entry.inApp,
                    enabled: entry.userConfigurable
                ) { newValue in
                    Task { await updateInApp(entry, to: newValue) }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func toggleRow(
        label: String,
        isOn: Bool,
        enabled: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(enabled ? .secondary : .tertiary)

            Toggle("", isOn: Binding(get: { isOn }, set: onChange))
                .labelsHidden()
                .scaleEffect(0.75)
                .frame(width: 38)
                .disabled(!enabled)
        }
    }

    // MARK: - Quiet hours

    private var quietHoursSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Quiet hours")

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: Binding(
                    get: { preferences.quietHours.enabled },
                    set: { newValue in Task { await updateQuietHours(enabled: newValue) } }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hold notifications overnight")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)

                        Text("They arrive when the window ends rather than being dropped.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(paletteManager.color(at: 0))

                if preferences.quietHours.enabled {
                    Divider().background(.white.opacity(0.1))

                    HStack {
                        hourPicker(
                            title: "From",
                            hour: preferences.quietHours.start
                        ) { newHour in
                            Task { await updateQuietHours(start: newHour) }
                        }

                        Spacer()

                        hourPicker(
                            title: "Until",
                            hour: preferences.quietHours.end
                        ) { newHour in
                            Task { await updateQuietHours(end: newHour) }
                        }
                    }

                    Text("Currently \(preferences.quietHours.displayRange) in your timezone.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color(UIColor.systemGray6).opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func hourPicker(title: String, hour: Int, onChange: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Menu {
                ForEach(0..<24, id: \.self) { h in
                    Button(QuietHours.hourLabel(h)) { onChange(h) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(QuietHours.hourLabel(hour))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(.ultraThinMaterial))
            }
        }
    }

    // MARK: - Pieces

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try again") {
                Task { await load() }
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(40)
    }

    private func saveErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Loading and saving

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus

        do {
            let result = try await NetworkService.shared.getNotificationPreferences()
            preferences = result.preferences
            pushConfigured = result.pushConfigured
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func requestPermission() async {
        _ = await NotificationManager.shared.requestAuthorization()
        // Registering here as well as at launch means the user does not have to
        // background the app before the first push can arrive.
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Optimistic, then reconciled with the server's answer.
    ///
    /// Only the one type is sent. The server applies a partial patch, so a save
    /// from this screen cannot revert a change the same user made on another
    /// device while this sheet was open.
    private func updatePush(_ entry: NotificationTypePreference, to value: Bool) async {
        await applyLocally(entry.type) { $0.push = value }

        savingType = entry.type
        defer { savingType = nil }

        do {
            preferences = try await NetworkService.shared.updateNotificationPreferences(
                types: [["type": entry.type, "push": value]]
            )
            saveError = nil
        } catch {
            // Put the switch back. A toggle that stays flipped after a failed
            // save is worse than an error, because it looks like it worked.
            await load()
            saveError = error.localizedDescription
        }
    }

    private func updateInApp(_ entry: NotificationTypePreference, to value: Bool) async {
        await applyLocally(entry.type) { $0.inApp = value }

        savingType = entry.type
        defer { savingType = nil }

        do {
            preferences = try await NetworkService.shared.updateNotificationPreferences(
                types: [["type": entry.type, "inApp": value]]
            )
            saveError = nil
        } catch {
            await load()
            saveError = error.localizedDescription
        }
    }

    private func updateQuietHours(
        enabled: Bool? = nil,
        start: Int? = nil,
        end: Int? = nil
    ) async {
        var body: [String: Any] = [:]
        if let enabled { body["enabled"] = enabled }
        if let start { body["start"] = start }
        if let end { body["end"] = end }

        savingType = "quietHours"
        defer { savingType = nil }

        do {
            preferences = try await NetworkService.shared.updateNotificationPreferences(quietHours: body)
            saveError = nil
        } catch {
            await load()
            saveError = error.localizedDescription
        }
    }

    private func applyLocally(_ type: String, _ mutate: (inout NotificationTypePreference) -> Void) async {
        guard let index = preferences.types.firstIndex(where: { $0.type == type }) else { return }
        mutate(&preferences.types[index])
    }
}

#Preview {
    NotificationSettingsView()
}
