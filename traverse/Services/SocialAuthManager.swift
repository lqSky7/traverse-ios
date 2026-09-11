//
//  SocialAuthManager.swift
//  traverse
//
//  Runs the WorkOS OAuth handshake for Google / GitHub / Apple sign-in inside a
//  secure system browser session and hands the authorization code back to the app.
//

import Foundation
import AuthenticationServices
import UIKit

enum SocialAuthError: LocalizedError {
    case cancelled
    case missingCode
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign-in was cancelled."
        case .missingCode:
            return "Sign-in did not return an authorization code. Please try again."
        case .couldNotStart:
            return "Could not open the sign-in window. Please try again."
        }
    }
}

/// Bridges `ASWebAuthenticationSession` into an async/await call.
///
/// The session opens the WorkOS authorization URL in a system-managed browser
/// (so the user's existing Google / GitHub / Apple session is reused) and
/// intercepts the redirect to the custom URL scheme registered in `Info.plist`.
final class SocialAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {

    static let shared = SocialAuthManager()

    /// Custom URL scheme registered under `CFBundleURLTypes` in `Info.plist`.
    /// This must also be registered as a redirect URI in the WorkOS dashboard.
    static let callbackScheme = "traverse"

    /// Redirect URI handed to the backend, which forwards it on to WorkOS.
    static let redirectURI = "traverse://auth/callback"

    /// Retained for the lifetime of the flow — `ASWebAuthenticationSession` is
    /// released (and the browser sheet dismissed) if nothing holds on to it.
    private var session: ASWebAuthenticationSession?

    private override init() {
        super.init()
    }

    /// Presents the WorkOS sign-in page and returns the captured authorization code.
    @MainActor
    func authenticate(url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    if let sessionError = error as? ASWebAuthenticationSessionError,
                       sessionError.code == .canceledLogin {
                        continuation.resume(throwing: SocialAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: SocialAuthError.missingCode)
                    return
                }

                let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
                let code = components?.queryItems?.first(where: { $0.name == "code" })?.value

                guard let code, !code.isEmpty else {
                    continuation.resume(throwing: SocialAuthError.missingCode)
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session

            if !session.start() {
                self.session = nil
                continuation.resume(throwing: SocialAuthError.couldNotStart)
            }
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
        return keyWindow ?? ASPresentationAnchor()
    }
}
