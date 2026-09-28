import SwiftUI

struct BillingView: View {
    @Environment(\.openURL) private var openURL
    @State private var status: SubscriptionStatusResponse?
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var showingCancelConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Current plan") {
                HStack(spacing: 12) {
                    Image(systemName: "creditcard.fill")
                        .foregroundStyle(ColorPaletteManager.shared.color(at: 1))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            isLoading
                                ? "Checking plan…"
                                : (status?.isSubscriptionActive == true
                                    ? (status?.planName ?? "Traverse Pro")
                                    : "Traverse Free")
                        )
                            .font(.headline)
                        Text(planDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if isLoading { ProgressView() }
                }
                .padding(.vertical, 4)

                if status?.isSubscriptionActive != true {
                    Button("Upgrade to Pro") { openBillingPage() }
                } else if status?.canCancel == true {
                    Button(role: .destructive) {
                        showingCancelConfirmation = true
                    } label: {
                        if isWorking { ProgressView() } else { Text("Cancel renewal") }
                    }
                    .disabled(isWorking)
                } else if status?.cancellationScheduled == true {
                    Label("Renewal cancelled", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Label("Adaptive revision scheduling", systemImage: "checkmark")
                Label("Deeper progress analytics", systemImage: "checkmark")
                Label("AI code analysis", systemImage: "checkmark")
                Button("Manage billing on the web") { openBillingPage() }
            } header: {
                Text("Traverse Pro")
            } footer: {
                Text("Changes to your subscription take effect at the end of the current billing period.")
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Billing")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadStatus() }
        .confirmationDialog(
            "Cancel your Traverse Pro renewal?",
            isPresented: $showingCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel renewal", role: .destructive) { Task { await cancelRenewal() } }
            Button("Keep Pro", role: .cancel) { }
        } message: {
            Text("Pro stays active until the end of your current billing period.")
        }
    }

    private var planDescription: String {
        guard !isLoading else { return "Loading your subscription details." }
        guard status?.isSubscriptionActive == true else { return "Upgrade whenever you’re ready." }
        if status?.cancellationScheduled == true {
            let endDate = formattedDate(status?.activeUntil) ?? "the end of this billing period"
            return "Renewal is cancelled. Pro remains active until \(endDate)."
        }
        if let date = formattedDate(status?.activeUntil) { return "Renews after \(date)." }
        return "Pro is active on your account."
    }

    @MainActor
    private func loadStatus() async {
        isLoading = true
        defer { isLoading = false }
        do {
            status = try await NetworkService.shared.getSubscriptionStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func cancelRenewal() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await NetworkService.shared.cancelSubscription()
            await loadStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openBillingPage() {
        if let url = URL(string: "https://traverses.tech/billing") { openURL(url) }
    }

    private func formattedDate(_ raw: String?) -> String? {
        guard let raw, let date = ISO8601DateFormatter().date(from: raw) else { return nil }
        return date.formatted(date: .long, time: .omitted)
    }
}
