import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    @State private var mode: AuthMode = .signIn
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var resetCode = ""
    @State private var newPassword = ""
    @State private var baseColor = Color.blue

    enum AuthMode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case create = "Create Account"
        case recover = "Recover"
        var id: String { rawValue }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 26) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(paletteManager.selectedPalette.primary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Traverse")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                    Text("Track solves, revise with intent, and keep your coding streak alive.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Stats and achievement dashboard", systemImage: "chart.bar.xaxis")
                    Label("Spaced revision schedule with ML mode", systemImage: "brain")
                    Label("Friends, requests, streaks, QR invite links", systemImage: "person.2.wave.2")
                    Label("Custom palette theming across charts", systemImage: "paintpalette")
                }
                .font(.headline)
                .foregroundStyle(.secondary)

                Spacer()
                PaletteStrip(palette: paletteManager.selectedPalette)
            }
            .padding(42)
            .frame(width: 480)

            VStack(spacing: 20) {
                Picker("Mode", selection: $mode) {
                    ForEach(AuthMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                ThemedCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(mode.rawValue)
                            .font(.title2.weight(.bold))

                        TextField("Username", text: $username)
                            .textFieldStyle(.roundedBorder)

                        if mode == .create {
                            TextField("Email", text: $email)
                                .textFieldStyle(.roundedBorder)
                        }

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)

                        if mode == .recover {
                            TextField("Reset code", text: $resetCode)
                                .textFieldStyle(.roundedBorder)
                            SecureField("New password", text: $newPassword)
                                .textFieldStyle(.roundedBorder)
                        }

                        if mode == .create {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Pick Your Hue")
                                    .font(.headline)
                                ColorPicker("Base color", selection: $baseColor, supportsOpacity: false)
                                Button("Apply Custom Palette") {
                                    paletteManager.createPalette(from: baseColor)
                                }
                            }
                            .padding(.top, 4)
                        }

                        Button(action: submit) {
                            Text(primaryButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        if mode == .recover {
                            HStack {
                                Button("Request reset code") {
                                    Task {
                                        do {
                                            let response = try await APIClient.shared.requestPasswordReset(username: username)
                                            appState.statusMessage = response.message
                                        } catch {
                                            appState.errorMessage = error.localizedDescription
                                        }
                                    }
                                }
                                Button("Confirm reset") {
                                    Task {
                                        do {
                                            try await APIClient.shared.confirmPasswordReset(username: username, code: resetCode, newPassword: newPassword)
                                            appState.statusMessage = "Password reset"
                                        } catch {
                                            appState.errorMessage = error.localizedDescription
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: 420)
            }
            .padding(42)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
        }
    }

    private var primaryButtonTitle: String {
        switch mode {
        case .signIn: "Sign In"
        case .create: "Create Account"
        case .recover: "Recover Account"
        }
    }

    private func submit() {
        Task {
            switch mode {
            case .signIn:
                await appState.login(username: username, password: password)
            case .create:
                await appState.register(username: username, email: email, password: password)
            case .recover:
                do {
                    let user = try await APIClient.shared.recoverAccount(username: username, password: password.isEmpty ? nil : password)
                    appState.user = user
                } catch {
                    appState.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
