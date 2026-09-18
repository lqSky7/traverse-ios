import Foundation
import UIKit
import UserNotifications

/// APNs registration and device-token upload.
///
/// Separate from `NotificationInboxManager` (which owns server state) and from
/// `NotificationManager` (which owns locally-scheduled reminders) because the
/// token has a lifecycle of its own: iOS can issue a new one at any time, the
/// upload needs a session, and the token must outlive a sign-out so the next
/// sign-in can re-register without waiting for iOS to hand it over again.
///
/// The token is cached in `UserDefaults`, not the keychain. It is not a secret —
/// it is an opaque address that only Apple's servers can deliver to, and it is
/// useless without the server-side signing key.
@MainActor
final class PushRegistrationService {
    static let shared = PushRegistrationService()

    private let tokenKey = "apnsDeviceToken"
    private let sandboxKey = "apnsTokenIsSandbox"

    private init() {}

    var cachedToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    /// Asks iOS for a token.
    ///
    /// Requires notification authorisation to already be granted: calling this
    /// before the user has answered the permission prompt gets a token that APNs
    /// will not deliver to. Called at launch when authorisation is already
    /// granted, and again right after the user grants it.
    func register() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Stores a token handed over by the app delegate and uploads it if a session
    /// exists.
    func handleRegistered(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        let sandbox = Self.isSandboxBuild

        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(sandbox, forKey: sandboxKey)

        print("[Push] registered token (\(sandbox ? "sandbox" : "production"))")

        Task { await uploadIfPossible() }
    }

    func handleRegistrationFailure(_ error: Error) {
        // Not fatal. Simulator builds cannot register, and a user who has
        // declined notifications will fail here too. The inbox is unaffected.
        print("[Push] registration failed: \(error.localizedDescription)")
    }

    /// Uploads the cached token. Safe to call repeatedly — the server upserts on
    /// the token, so a re-upload is a no-op update rather than a new row.
    func uploadIfPossible() async {
        guard let token = cachedToken, KeychainHelper.shared.getToken() != nil else {
            return
        }

        let sandbox = UserDefaults.standard.bool(forKey: sandboxKey)

        do {
            try await NetworkService.shared.registerPushToken(
                token,
                sandbox: sandbox,
                deviceId: UIDevice.current.identifierForVendor?.uuidString
            )
        } catch {
            // Retried on the next launch or sign-in. A failed upload here means
            // this device gets no pushes until then, which is the right amount
            // of consequence for a transient network error.
            print("[Push] token upload failed: \(error.localizedDescription)")
        }
    }

    /// Detaches this device from the signed-out account.
    ///
    /// The local token is kept: it is still this device's token and the next
    /// sign-in should reuse it rather than waiting for iOS to reissue.
    func unregisterFromServer() async {
        guard let token = cachedToken else { return }

        do {
            try await NetworkService.shared.unregisterPushToken(token)
        } catch {
            print("[Push] token unregister failed: \(error.localizedDescription)")
        }
    }

    /// Whether this build talks to the sandbox or production APNs.
    ///
    /// This is a property of the *build*, because that is what determines which
    /// APNs environment the token was minted in — a debug build gets a sandbox
    /// token, TestFlight and App Store builds get production tokens. Getting it
    /// wrong means every push is rejected with `BadDeviceToken`, so it is
    /// derived from the compilation configuration rather than guessed at
    /// runtime.
    static var isSandboxBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
