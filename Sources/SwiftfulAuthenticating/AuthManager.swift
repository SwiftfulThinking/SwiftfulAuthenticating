import Foundation

@MainActor
@Observable
public class AuthManager {
    private let logger: AuthLogger?
    private let service: AuthService

    public private(set) var auth: UserAuthInfo?
    private var taskListener: Task<Void, Error>?

    public init(service: AuthService, logger: AuthLogger? = nil) {
        self.service = service
        self.logger = logger
        self.auth = service.getAuthenticatedUser()
        self.addAuthListener()
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
        self.auth = value

        if let value {
            self.logger?.identifyUser(userId: value.uid, name: value.displayName, email: value.email)
            self.logger?.addUserProperties(dict: value.eventParameters, isHighPriority: true)
            self.logger?.trackEvent(event: Event.authListenerSuccess(user: value))
        } else {
            self.logger?.trackEvent(event: Event.authlistenerEmpty)
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

    private func signIn(option: SignInOption) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        self.logger?.trackEvent(event: Event.signInStart(option: option))
        
        defer {
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

        do {
            try service.signOut()
            auth = nil
            logger?.trackEvent(event: Event.signOutSuccess)
        } catch {
            logger?.trackEvent(event: Event.signOutFail(error: error))
            throw error
        }
    }

    public func deleteAccount() async throws {
        self.logger?.trackEvent(event: Event.deleteAccountStart)

        do {
            try await service.deleteAccount()
            auth = nil
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
            default:
                return nil
            }
        }

        var type: AuthLogType {
            switch self {
            case .signInFail, .signOutFail, .deleteAccountFail:
                return .severe
            case .authlistenerEmpty:
                return .warning
            default:
                return .info
            }
        }
    }
}

