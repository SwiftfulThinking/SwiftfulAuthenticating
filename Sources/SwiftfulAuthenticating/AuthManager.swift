import Foundation

@MainActor
@Observable
public class AuthManager {
    private let logger: AuthLogger?
    private let service: AuthService

    public private(set) var auth: UserAuthInfo?
    private var taskListener: Task<Void, Error>?

    // MARK: Real-account marker + re-auth prompt budget

    private let markerStore: RealAccountMarkerStore
    public let reauthPromptPolicy: ReauthPromptPolicy

    /// Marker from the device-local keychain: the SAME device had a real account (survives reinstall).
    public private(set) var realAccountMarkerOnThisDevice: RealAccountMarker?
    /// Marker from the iCloud-synced keychain: this iCloud identity had a real account anywhere.
    public private(set) var realAccountMarkerOnAnyDevice: RealAccountMarker?
    /// Re-auth prompts the user has declined since the last real sign-in. Persisted in UserDefaults.
    public private(set) var reauthPromptDeclineCount: Int {
        didSet { UserDefaults.standard.set(reauthPromptDeclineCount, forKey: AuthManager.declineCountKey) }
    }
    private static let declineCountKey = "swiftful_auth_reauth_prompt_decline_count"

    /// TRUE while signOut / deleteAccount runs, so the nil that follows is not reported as a lost session.
    private var isExplicitSignOutInProgress: Bool = false
    /// TRUE while signIn runs: linking an anonymous account can publish a transient nil during the SDK handshake.
    private var isSignInInProgress: Bool = false

    public init(
        service: AuthService,
        logger: AuthLogger? = nil,
        markerStore: RealAccountMarkerStore = KeychainRealAccountMarkerStore(),
        reauthPromptPolicy: ReauthPromptPolicy = ReauthPromptPolicy()
    ) {
        self.service = service
        self.logger = logger
        self.markerStore = markerStore
        self.reauthPromptPolicy = reauthPromptPolicy
        self.realAccountMarkerOnThisDevice = markerStore.read(source: .thisDevice)
        self.realAccountMarkerOnAnyDevice = markerStore.read(source: .anyDevice)
        self.reauthPromptDeclineCount = UserDefaults.standard.integer(forKey: AuthManager.declineCountKey)
        self.auth = service.getAuthenticatedUser()
        self.addAuthListener()
        recordRealAccountIfNeeded(user: auth)
    }

    /// TRUE if THIS device authenticated as a real (non-anonymous) account and never explicitly signed out.
    public var hadPreviousRealAccount: Bool {
        realAccountMarkerOnThisDevice != nil
    }

    /// TRUE if this device OR this iCloud identity authenticated as a real account and never explicitly signed out.
    public var hadPreviousRealAccountOnAnyDevice: Bool {
        realAccountMarkerOnThisDevice != nil || realAccountMarkerOnAnyDevice != nil
    }

    /// The uid of the last real account seen here (device-local first, then synced).
    public var lastRealAccountUid: String? {
        (realAccountMarkerOnThisDevice ?? realAccountMarkerOnAnyDevice)?.uid
    }

    /// The provider the last real account signed in with (device-local first, then synced). Use it to
    /// pre-select the sign-in button on the re-auth prompt.
    public var lastSignInProvider: AuthProviderOption? {
        (realAccountMarkerOnThisDevice ?? realAccountMarkerOnAnyDevice)?.provider
    }

    /// Which marker currently drives the re-auth prompt, for analytics.
    public var reauthPromptMarkerSource: RealAccountMarkerSource? {
        if realAccountMarkerOnThisDevice != nil { return .thisDevice }
        if realAccountMarkerOnAnyDevice != nil { return .anyDevice }
        return nil
    }

    /// TRUE when the app should NOT mint a replacement anonymous account: there is no session, THIS device
    /// had a real account (the session was revoked out from under the user — password reset, credential change,
    /// provider takeover), and the user has not exhausted the prompt budget. Minting here is what silently
    /// destroyed accounts: the anonymous uid replaces the real one and purchases follow it. Prompt instead.
    public var shouldBlockAnonMintForReauthentication: Bool {
        auth == nil
            && hadPreviousRealAccount
            && reauthPromptDeclineCount < reauthPromptPolicy.maxDeclines
    }

    /// TRUE when the app should present the "sign back in" prompt: the user is NOT on a real account
    /// (no session, or the anonymous account minted after a decline) while a marker says a real account lived
    /// here or on this iCloud identity. Keyed on the ANY-device marker so reinstall / new-device arrivals,
    /// who restore no session and mint on first launch, are reached too. Every decline spends a strike.
    public var shouldPromptForReauthentication: Bool {
        (auth == nil || auth?.isAnonymous == true)
            && hadPreviousRealAccountOnAnyDevice
            && reauthPromptDeclineCount < reauthPromptPolicy.maxDeclines
    }

    /// Call when the user dismisses the re-auth prompt without ending up on a real account.
    public func recordReauthPromptDeclined() {
        reauthPromptDeclineCount += 1
        logger?.trackEvent(event: Event.reauthPromptDeclined(count: reauthPromptDeclineCount, max: reauthPromptPolicy.maxDeclines))
    }

    /// Write the marker for a real (non-anonymous) session and reset the decline budget. No-op for nil / anonymous.
    private func recordRealAccountIfNeeded(user: UserAuthInfo?) {
        guard let user, !user.isAnonymous else { return }
        let marker = RealAccountMarker(uid: user.uid, provider: user.authProviders.first)
        markerStore.write(marker)
        realAccountMarkerOnThisDevice = marker
        realAccountMarkerOnAnyDevice = marker
        if reauthPromptDeclineCount != 0 {
            reauthPromptDeclineCount = 0
        }
    }

    /// Explicit sign-out / delete: the user chose to leave, so no re-auth prompt should follow.
    private func clearRealAccountMarker() {
        markerStore.clear()
        realAccountMarkerOnThisDevice = nil
        realAccountMarkerOnAnyDevice = nil
        reauthPromptDeclineCount = 0
    }

    public func getAuthId() throws -> String {
        guard let uid = auth?.uid else {
            throw AuthError.notSignedIn
        }

        return uid
    }

    private func addAuthListener() {        
        // Attach new listener
        taskListener?.cancel()
        taskListener = Task {
            for await value in service.addAuthenticatedUserListener() {
                setCurrentAuth(auth: value)
            }
        }
    }
    
    private func setCurrentAuth(auth value: UserAuthInfo?) {
        let previous = self.auth
        self.auth = value

        if let value {
            self.logger?.identifyUser(userId: value.uid, name: value.displayName, email: value.email)
            self.logger?.addUserProperties(dict: value.eventParameters, isHighPriority: true)
            self.logger?.trackEvent(event: Event.authListenerSuccess(user: value))
            recordRealAccountIfNeeded(user: value)
        } else {
            self.logger?.trackEvent(event: Event.authlistenerEmpty)

            // The SDK silently dropped an authenticated session (token refresh failed after a server-side
            // revocation — password/email change, disabled account, deleted user). Explicit sign-out and the
            // link handshake are filtered. The marker stays, so the app can prompt instead of minting.
            if let previous, !isExplicitSignOutInProgress, !isSignInInProgress {
                self.logger?.trackEvent(event: Event.sessionLost(user: previous, marker: realAccountMarkerOnThisDevice))
            }
        }
    }
    
    @discardableResult
    public func signInAnonymously() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        let result = try await signIn(option: .anonymous)
        setCurrentAuth(auth: result.user)
        return result
    }
    
    @discardableResult
    public func signInApple() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        try await signIn(option: .apple)
    }
    
    @discardableResult
    public func signInGoogle(GIDClientID: String) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        try await signIn(option: .google(GIDClientID: GIDClientID))
    }

    @discardableResult
    public func signIn(option: SignInOption) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        self.logger?.trackEvent(event: Event.signInStart(option: option))
        isSignInInProgress = true
        
        defer {
            isSignInInProgress = false
            // After user's auth changes, re-attach auth listener.
            // This isn't usually necessary, but if the user is "linking" to an anonymous account,
            // The Firebase auth listener does not auto-publish new value (since it's the same UID).
            // Re-adding a new listener should catch any catch edge cases.
            addAuthListener()
        }

        do {
            let result = try await service.signIn(option: option)
            setCurrentAuth(auth: result.user)
            logger?.trackEvent(event: Event.signInSuccess(option: option, user: result.user, isNewUser: result.isNewUser))
            return result
        } catch {
            logger?.trackEvent(event: Event.signInFail(error: error))
            throw error
        }
    }

    public func signOut() throws {
        self.logger?.trackEvent(event: Event.signOutStart)
        isExplicitSignOutInProgress = true
        defer { isExplicitSignOutInProgress = false }

        do {
            try service.signOut()
            auth = nil
            clearRealAccountMarker()
            logger?.trackEvent(event: Event.signOutSuccess)
        } catch {
            logger?.trackEvent(event: Event.signOutFail(error: error))
            throw error
        }
    }
    
    public func deleteAccount() async throws {
        self.logger?.trackEvent(event: Event.deleteAccountStart)
        isExplicitSignOutInProgress = true
        defer { isExplicitSignOutInProgress = false }
        
        do {
            try await service.deleteAccount()
            
            auth = nil
            clearRealAccountMarker()
            logger?.trackEvent(event: Event.deleteAccountSuccess)
        } catch {
            logger?.trackEvent(event: Event.deleteAccountFail(error: error))
            throw error
        }
    }

    public func deleteAccountWithReauthentication(option: SignInOption, revokeToken: Bool, performDeleteActionsBeforeAuthIsDeleted: (() async throws -> Void)? = nil) async throws {
        self.logger?.trackEvent(event: Event.deleteAccountStart)
        isExplicitSignOutInProgress = true
        defer { isExplicitSignOutInProgress = false }

        do {
            try await service.deleteAccountWithReauthentication(option: option, revokeToken: revokeToken, performDeleteActionsBeforeAuthIsDeleted: {
                try await performDeleteActionsBeforeAuthIsDeleted?()
            })
            
            auth = nil
            clearRealAccountMarker()
            logger?.trackEvent(event: Event.deleteAccountSuccess)
        } catch {
            logger?.trackEvent(event: Event.deleteAccountFail(error: error))
            throw error
        }
    }

    public enum AuthError: Error {
        case notSignedIn
    }

}

extension AuthManager {
    enum Event: AuthLogEvent {
        case authListenerSuccess(user: UserAuthInfo)
        case authlistenerEmpty
        case signInStart(option: SignInOption)
        case signInSuccess(option: SignInOption, user: UserAuthInfo, isNewUser: Bool)
        case signInFail(error: Error)
        case signOutStart
        case signOutSuccess
        case signOutFail(error: Error)
        case deleteAccountStart
        case deleteAccountSuccess
        case deleteAccountFail(error: Error)
        case sessionLost(user: UserAuthInfo, marker: RealAccountMarker?)
        case reauthPromptDeclined(count: Int, max: Int)

        var eventName: String {
            switch self {
            case .authListenerSuccess: return         "Auth_Listener_Success"
            case .authlistenerEmpty: return           "Auth_Listener_Empty"
            case .signInStart: return                 "Auth_SignIn_Start"
            case .signInSuccess: return               "Auth_SignIn_Success"
            case .signInFail: return                  "Auth_SignIn_Fail"
            case .signOutStart: return                "Auth_SignOut_Start"
            case .signOutSuccess: return              "Auth_SignOut_Success"
            case .signOutFail: return                 "Auth_SignOut_Fail"
            case .deleteAccountStart: return          "Auth_DeleteAccount_Start"
            case .deleteAccountSuccess: return        "Auth_DeleteAccount_Success"
            case .deleteAccountFail: return           "Auth_DeleteAccount_Fail"
            case .sessionLost: return                 "Auth_SessionLost"
            case .reauthPromptDeclined: return        "Auth_ReauthPrompt_Declined"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .authListenerSuccess(user: let user):
                return user.eventParameters
            case .signInStart(option: let option):
                return option.eventParameters
            case .signInSuccess(option: let option, user: let user, isNewUser: let isNewUser):
                var dict = user.eventParameters
                dict.merge(option.eventParameters)
                dict["is_new_user"] = isNewUser
                return dict
            case .signInFail(error: let error), .signOutFail(error: let error), .deleteAccountFail(error: let error):
                return error.eventParameters
            case .sessionLost(user: let user, marker: let marker):
                var dict: [String: Any] = [
                    "lost_uid": user.uid,
                    "lost_uid_was_anonymous": user.isAnonymous,
                    "had_real_account_marker": marker != nil
                ]
                dict.merge(marker?.eventParameters ?? [:])
                return dict
            case .reauthPromptDeclined(count: let count, max: let max):
                return ["decline_count": count, "max_declines": max]
            default:
                return nil
            }
        }

        var type: AuthLogType {
            switch self {
            case .signInFail, .signOutFail, .deleteAccountFail:
                return .severe
            case .authlistenerEmpty, .sessionLost:
                return .warning
            case .reauthPromptDeclined:
                return .analytic
            default:
                return .info
            }
        }
    }
}

