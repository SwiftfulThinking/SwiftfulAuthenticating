import Foundation
import SwiftfulLogging

@MainActor
@Observable
public class AuthManager {
    private let logger: LogManager
    private let service: AuthService

    public private(set) var auth: UserAuthInfo?
    private var listener: (any NSObjectProtocol)?

    public init(service: AuthService, logger: LogManager = LogManager(services: [])) {
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
        Task {
            for await value in service.addAuthenticatedUserListener(onListenerAttached: { listener in
                self.listener = listener
            }) {
                self.auth = value

                if let value {
                    self.logger.identifyUser(userId: value.uid, name: value.displayName, email: value.email)
                    self.logger.addUserProperties(dict: value.eventParameters.sendable())
                    self.logger.trackEvent(event: Event.authListenerSuccess(user: value))
                } else {
                    self.logger.trackEvent(event: Event.authlistenerEmpty)
                }
            }
        }
    }
    
    @discardableResult
    public func signInAnonymous() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        try await signIn(option: .anonymous)
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
        self.logger.trackEvent(event: Event.signInStart(option: option))

        do {
            let (user, isNewUser) = try await service.signIn(option: option)
            logger.trackEvent(event: Event.signInSuccess(option: option, user: user, isNewUser: isNewUser))
            return (user, isNewUser)
        } catch {
            logger.trackEvent(event: Event.signInFail(error: error))
            throw error
        }
    }

    public func signOut() throws {
        self.logger.trackEvent(event: Event.signOutStart)

        do {
            try service.signOut()
            auth = nil
            logger.trackEvent(event: Event.signOutSuccess)
        } catch {
            logger.trackEvent(event: Event.signOutFail(error: error))
            throw error
        }
    }

    public func deleteAccount() async throws {
        self.logger.trackEvent(event: Event.deleteAccountStart)

        do {
            try await service.deleteAccount()
            auth = nil
            logger.trackEvent(event: Event.deleteAccountSuccess)
        } catch {
            logger.trackEvent(event: Event.deleteAccountFail(error: error))
            throw error
        }
    }

    public enum AuthError: Error {
        case notSignedIn
    }

}

extension AuthManager {
    enum Event: LoggableEvent {
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

        var type: LogType {
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

