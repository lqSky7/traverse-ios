import SwiftUI

struct ActiveSessionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var response: AuthSessionsResponse?
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var notice: String?
    @State private var sessionToRevoke: AuthSession?
    @State private var showingSessionConfirmation = false
    @State private var showingOthersConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && response == nil {
                    ProgressView("Loading sessions…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, response == nil {
                    ContentUnavailableView {
                        Label("Sessions unavailable", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try again") {
                            Task { await loadSessions() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let response {
                    sessionsList(response)
                } else {
                    ContentUnavailableView(
                        "No active sessions",
                        systemImage: "laptopcomputer.and.iphone",
                        description: Text("Signed-in devices will appear here.")
                    )
                }
            }
            .navigationTitle("Active Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadSessions() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh sessions")
                    .disabled(isLoading || isWorking)
                }
            }
            .task { await loadSessions() }
            .refreshable { await loadSessions() }
            .confirmationDialog(
                "Sign out this device?",
                isPresented: $showingSessionConfirmation,
                presenting: sessionToRevoke
            ) { session in
                Button("Sign out \(session.deviceName)", role: .destructive) {
                    Task { await revoke(session) }
                }
                Button("Cancel", role: .cancel) { sessionToRevoke = nil }
            } message: { _ in
                Text("This device will need to sign in again.")
            }
            .confirmationDialog(
                "Sign out other devices?",
                isPresented: $showingOthersConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign out other devices", role: .destructive) {
                    Task { await revokeOtherSessions() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This device will stay signed in. Other active sessions will be revoked.")
            }
            .alert("Active Sessions", isPresented: Binding(
                get: { (errorMessage != nil && response != nil) || notice != nil },
                set: { if !$0 { errorMessage = nil; notice = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil; notice = nil }
            } message: {
                Text(errorMessage ?? notice ?? "")
            }
        }
    }

    @ViewBuilder
    private func sessionsList(_ response: AuthSessionsResponse) -> some View {
        List {
            Section {
                ForEach(response.sessions) { session in
                    SessionRow(session: session) {
                        sessionToRevoke = session
                        showingSessionConfirmation = true
                    }
                }
            } header: {
                Text("Signed-in devices · \(response.sessions.count) of \(response.maxSessions)")
            } footer: {
                Text("You can keep up to \(response.maxSessions) devices signed in at once.")
            }

            if response.sessions.contains(where: { !$0.isCurrent }) {
                Section {
                    Button(role: .destructive) {
                        showingOthersConfirmation = true
                    } label: {
                        if isWorking {
                            ProgressView()
                        } else {
                            Text("Sign out other devices")
                        }
                    }
                    .disabled(isWorking)
                } footer: {
                    Text("Your current device stays signed in.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if response.sessions.isEmpty {
                ContentUnavailableView(
                    "No active sessions",
                    systemImage: "laptopcomputer.and.iphone",
                    description: Text("Signed-in devices will appear here.")
                )
            }
        }
    }

    private func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            response = try await NetworkService.shared.getAuthSessions()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revoke(_ session: AuthSession) async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await NetworkService.shared.revokeAuthSession(id: session.id)
            sessionToRevoke = nil
            await loadSessions()
            notice = "Device signed out."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revokeOtherSessions() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await NetworkService.shared.revokeOtherAuthSessions()
            await loadSessions()
            notice = "\(result.revokedCount ?? 0) other session(s) signed out."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SessionRow: View {
    let session: AuthSession
    let onRevoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: session.isCurrent ? "iphone" : "laptopcomputer.and.iphone")
                    .font(.title3)
                    .foregroundStyle(session.isCurrent ? Color.accentColor : Color.secondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(session.deviceName)
                            .font(.headline)
                        if session.isCurrent {
                            Text("THIS DEVICE")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                    }
                    Text("Last active \(formatSessionDate(session.lastSeenAt))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let ipAddress = session.ipAddress, !ipAddress.isEmpty {
                        Text(ipAddress)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if !session.isCurrent {
                Button("Revoke session", role: .destructive, action: onRevoke)
                    .font(.subheadline.weight(.medium))
                    .padding(.leading, 40)
            }
        }
        .padding(.vertical, 5)
    }

    private func formatSessionDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
