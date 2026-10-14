//
//  ReauthPromptPolicy.swift
//  SwiftfulAuthenticating
//
//  Created by Nick Sarno on 10/8/26.
//
import Foundation

/// Policy for the "sign back in" prompt shown when a real account's session is lost out from under the user.
///
/// No session + marker => the app should NOT mint a replacement anonymous account
/// (`AuthManager.shouldBlockAnonMintForReauthentication`) and should prompt instead
/// (`AuthManager.shouldPromptForReauthentication`). Declining spends one strike; a real sign-in resets them.
public struct ReauthPromptPolicy: Sendable {
    /// Total prompts a user can decline before the app stops asking (and mints as usual).
    public let maxDeclines: Int
    /// Minimum gap between prompt appearances within one long-lived app process (re-prompt on a later foreground).
    public let foregroundRepromptInterval: TimeInterval

    public init(maxDeclines: Int = 10, foregroundRepromptInterval: TimeInterval = 60 * 60 * 12) {
        self.maxDeclines = maxDeclines
        self.foregroundRepromptInterval = foregroundRepromptInterval
    }
}
