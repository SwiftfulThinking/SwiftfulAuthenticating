# SwiftfulAuthenticating

Observable authentication framework for Swift 6. `AuthManager` wraps an `AuthService` implementation (Mock, Firebase) through a single API. iOS 17+, macOS 14+.

## API

### AuthManager

`@MainActor @Observable` class. All authentication goes through this single entry point.

```swift
let authManager = AuthManager(service: AuthService, logger: AuthLogger? = nil)

authManager.auth                    // UserAuthInfo? — current authenticated user (observable)
authManager.getAuthId()             // throws -> String

authManager.signIn(option: SignInOption)  // async throws -> (user: UserAuthInfo, isNewUser: Bool)
authManager.signInAnonymously()          // async throws -> (user: UserAuthInfo, isNewUser: Bool)
authManager.signInApple()                // async throws -> (user: UserAuthInfo, isNewUser: Bool)
authManager.signInGoogle(GIDClientID:)   // async throws -> (user: UserAuthInfo, isNewUser: Bool)

authManager.signOut()               // throws (NOT async)
authManager.deleteAccount()         // async throws
authManager.deleteAccountWithReauthentication(option:revokeToken:performDeleteActionsBeforeAuthIsDeleted:)  // async throws
```

**IMPORTANT**: `auth` is optional (`UserAuthInfo?`). Always use optional chaining: `authManager.auth?.uid`, not `authManager.auth.uid`.

**IMPORTANT**: `signOut()` is synchronous — do NOT use `await` with it: `try authManager.signOut()`.

**IMPORTANT**: All sign-in methods return a tuple `(user: UserAuthInfo, isNewUser: Bool)`. Use `isNewUser` to decide whether to create a new user profile or load an existing one.

### AuthService Protocol

```swift
@MainActor
public protocol AuthService: Sendable {
    func getAuthenticatedUser() -> UserAuthInfo?
    func addAuthenticatedUserListener() -> AsyncStream<UserAuthInfo?>
    func signIn(option: SignInOption) async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func signOut() throws
    func deleteAccount() async throws
    func deleteAccountWithReauthentication(option: SignInOption, revokeToken: Bool, performDeleteActionsBeforeAuthIsDeleted: () async throws -> Void) async throws
}
```

### Available Service Implementations

```swift
import SwiftfulAuthenticating              // MockAuthService (included)
import SwiftfulAuthenticatingFirebase      // FirebaseAuthService()
```

### MockAuthService

For SwiftUI previews and testing:

```swift
// User is not yet authenticated
let service = MockAuthService(user: nil)

// User is already authenticated
let service = MockAuthService(user: .mock())
```

### SignInOption

```swift
public enum SignInOption: Sendable {
    case apple
    case anonymous
    case google(GIDClientID: String)
}
```

### AuthProviderOption

```swift
public enum AuthProviderOption: String, Codable, Sendable, CaseIterable {
    case google, apple, email, phone, facebook, gameCenter, github
}
```

### UserAuthInfo

```swift
public struct UserAuthInfo: Codable, Sendable {
    public let uid: String
    public let email: String?
    public let isAnonymous: Bool
    public let authProviders: [AuthProviderOption]
    public let displayName: String?
    public let firstName: String?
    public let lastName: String?
    public let phoneNumber: String?
    public let photoURL: URL?
    public let creationDate: Date?
    public let lastSignInDate: Date?

    public var name: String?              // computed: displayName ?? firstName + lastName
    public var eventParameters: [String: Any]  // computed: all fields prefixed with "uauth_"

    public static func mock(isAnonymous: Bool = false) -> Self
}
```

### SwiftfulAuthUI

Optional UI library included in the same package (separate import):

```swift
import SwiftfulAuthUI

SignInAppleButtonView()       // Apple sign-in button
    .frame(height: 50)

SignInGoogleButtonView()      // Google sign-in button
    .frame(height: 50)

SignInAnonymousButtonView()   // Anonymous/guest button
    .frame(height: 50)
```

## Usage Guide

### Service configuration by environment

```swift
// Mock / Testing — not authenticated
let authManager = AuthManager(service: MockAuthService(user: nil), logger: logManager)

// Mock / Testing — pre-authenticated
let authManager = AuthManager(service: MockAuthService(user: .mock()), logger: logManager)

// Development & Production — Firebase
let authManager = AuthManager(service: FirebaseAuthService(), logger: logManager)
```

### Sign-in flow pattern

All sign-in methods return `(user: UserAuthInfo, isNewUser: Bool)`. The standard pattern is:

```swift
do {
    let (user, isNewUser) = try await authManager.signInApple()

    if isNewUser {
        // Create new user profile in Firestore
    } else {
        // Load existing user profile
    }
} catch {
    // Handle auth failure
}
```

### Anonymous-first authentication

A common pattern is to sign in anonymously on first launch, then link to an SSO provider later. When an anonymous user signs in with Apple/Google, Firebase automatically links the accounts (same UID).

```swift
// App launch — sign in anonymously if no existing auth
func checkUserStatus() async {
    if let auth = authManager.auth {
        // Existing user — load profile
        try await logIn(user: auth, isNewUser: false)
    } else {
        // No auth — sign in anonymously
        let (user, isNewUser) = try await authManager.signInAnonymously()
        try await logIn(user: user, isNewUser: isNewUser)
    }
}

// Later — user taps "Sign in with Apple" on create account screen
func onSignInApplePressed() async throws {
    let (user, isNewUser) = try await authManager.signInApple()
    // Anonymous account is now linked to Apple
    try await logIn(user: user, isNewUser: isNewUser)
}
```

### Sign-out flow

`signOut()` is synchronous. After signing out, also sign out of all other managers:

```swift
func signOut() async throws {
    try authManager.signOut()
    try await purchaseManager.logOut()
    userManager.signOut()
    // ... sign out of any other managers
}
```

### Account deletion with reauthentication

The safe deletion pattern re-authenticates the user, performs cleanup (e.g. deleting Firestore data) inside the closure *before* auth is revoked, then deletes auth:

```swift
func deleteAccount() async throws {
    guard let auth = authManager.auth else { return }

    // Determine reauthentication option based on auth provider
    var option: SignInOption = .anonymous
    if auth.authProviders.contains(.apple) {
        option = .apple
    } else if auth.authProviders.contains(.google), let clientId = googleClientId {
        option = .google(GIDClientID: clientId)
    }

    try await authManager.deleteAccountWithReauthentication(
        option: option,
        revokeToken: false
    ) {
        // This closure runs AFTER reauthentication but BEFORE auth deletion.
        // Delete user data here while they still have auth access.
        try await userManager.deleteCurrentUser()
    }

    // Clean up other services after auth is deleted
    try await purchaseManager.logOut()
    logManager.deleteUserProfile()
}
```

**IMPORTANT**: The `performDeleteActionsBeforeAuthIsDeleted` closure must contain any Firestore/database deletions. Once auth is revoked, security rules will block the user from reading/writing their data.

### Google Sign-In requires GIDClientID

Google sign-in requires passing the Firebase client ID. Get it from `GoogleService-Info.plist`:

```swift
func signInGoogle() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
    guard let clientId = FirebaseApp.app()?.options.clientID else {
        throw AppError("Firebase not configured or clientID missing")
    }
    return try await authManager.signInGoogle(GIDClientID: clientId)
}
```

## Logger Protocol

SwiftfulAuthenticating defines its own logger protocol. The consuming app makes `LogManager` conform via retroactive conformance.

### AuthLogger Protocol

```swift
@MainActor
public protocol AuthLogger {
    func identifyUser(userId: String, name: String?, email: String?)
    func trackEvent(event: AuthLogEvent)
    func addUserProperties(dict: [String: Any], isHighPriority: Bool)
}

public protocol AuthLogEvent {
    var eventName: String { get }
    var parameters: [String: Any]? { get }
    var type: AuthLogType { get }
}

public enum AuthLogType: Int, CaseIterable, Sendable {
    case info      // 0
    case analytic  // 1
    case warning   // 2
    case severe    // 3
}
```

### Retroactive conformance (in consuming app)

```swift
import SwiftfulAuthenticating
import SwiftfulLogging

extension AuthLogType {
    var type: LogType {
        switch self {
        case .info:     return .info
        case .analytic: return .analytic
        case .warning:  return .warning
        case .severe:   return .severe
        }
    }
}

extension LogManager: @retroactive AuthLogger {
    public func trackEvent(event: any AuthLogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type.type)
    }
}
```

This allows passing `logManager` as the `logger:` parameter when creating `AuthManager`.

### Type aliases (recommended)

To avoid fully-qualified names throughout the app:

```swift
import SwiftfulAuthenticating
import SwiftfulAuthenticatingFirebase

public typealias UserAuthInfo = SwiftfulAuthenticating.UserAuthInfo
typealias AuthManager = SwiftfulAuthenticating.AuthManager
typealias MockAuthService = SwiftfulAuthenticating.MockAuthService
typealias FirebaseAuthService = SwiftfulAuthenticatingFirebase.FirebaseAuthService
typealias SignInOption = SwiftfulAuthenticating.SignInOption
```

### Built-in AuthManager logging

AuthManager logs these events internally when a logger is provided:

| Event | Type | When |
|---|---|---|
| `Auth_Listener_Success` | .info | Auth listener receives authenticated user |
| `Auth_Listener_Empty` | .warning | Auth listener receives nil |
| `Auth_SignIn_Start` | .info | Sign-in attempt begins |
| `Auth_SignIn_Success` | .info | Sign-in succeeds |
| `Auth_SignIn_Fail` | .severe | Sign-in fails |
| `Auth_SignOut_Start` | .info | Sign-out begins |
| `Auth_SignOut_Success` | .info | Sign-out succeeds |
| `Auth_SignOut_Fail` | .severe | Sign-out fails |
| `Auth_DeleteAccount_Start` | .info | Account deletion begins |
| `Auth_DeleteAccount_Success` | .info | Account deletion succeeds |
| `Auth_DeleteAccount_Fail` | .severe | Account deletion fails |

These are logged by the AuthManager itself — you do NOT need to log them in your Presenter/ViewModel. Presenter-layer events should track user intent (e.g. "CreateAccountView_AppleAuth_Start"), not the auth operation itself.

## Architecture Examples

### MVC (pure SwiftUI) — @Environment

```swift
struct CreateAccountView: View {
    @Environment(AuthManager.self) var authManager

    var body: some View {
        Button("Sign in with Apple") {
            Task {
                do {
                    let (user, isNewUser) = try await authManager.signInApple()
                    // handle success
                } catch {
                    // handle error
                }
            }
        }
    }
}
```

### MVVM — pass AuthManager to ViewModel

```swift
@Observable
@MainActor
class CreateAccountViewModel {
    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    func onSignInApplePressed() async {
        do {
            let (user, isNewUser) = try await authManager.signInApple()
            // handle success
        } catch {
            // handle error
        }
    }
}
```

### VIPER — Screen-specific interactors extend GlobalInteractor

Auth methods are NOT on `GlobalInteractor`. Each screen defines its own interactor protocol with only the auth methods it needs. `CoreInteractor` implements all of them.

```swift
// GlobalInteractor — shared across all screens (logging, haptics, sounds)
@MainActor
protocol GlobalInteractor {
    func trackEvent(eventName: String, parameters: [String: Any]?, type: LogType)
    func trackEvent(event: AnyLoggableEvent)
    func trackEvent(event: LoggableEvent)
    func trackScreenEvent(event: LoggableEvent)
    // ... haptics, sound effects
}

// Screen-specific interactor — only declares the auth methods this screen needs
@MainActor
protocol CreateAccountInteractor: GlobalInteractor {
    func signInApple() async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func signInGoogle() async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws
}

extension CoreInteractor: CreateAccountInteractor { }

// Other screens declare their own auth needs:
// AppViewInteractor: auth, signInAnonymously(), logIn()
// SettingsInteractor: auth, signOut(), deleteAccount()

// CoreInteractor has ALL auth methods, but each screen only sees what it declares
struct CoreInteractor {
    private let authManager: AuthManager

    var auth: UserAuthInfo? { authManager.auth }

    func signInApple() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        try await authManager.signInApple()
    }

    func signInGoogle() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        guard let clientId = Constants.firebaseAppClientId else {
            throw AppError("Firebase not configured or clientID missing")
        }
        return try await authManager.signInGoogle(GIDClientID: clientId)
    }

    func signOut() async throws {
        try authManager.signOut()
        try await purchaseManager.logOut()
        userManager.signOut()
        // ... sign out of other managers
    }

    // ... other methods
}

// Presenter defines events and calls its screen-specific interactor
@Observable
@MainActor
class CreateAccountPresenter {
    private let interactor: CreateAccountInteractor

    enum Event: LoggableEvent {
        case appleAuthStart
        case appleAuthSuccess(user: UserAuthInfo, isNewUser: Bool)
        case appleAuthFail(error: Error)

        var eventName: String {
            switch self {
            case .appleAuthStart:   return "CreateAccountView_AppleAuth_Start"
            case .appleAuthSuccess: return "CreateAccountView_AppleAuth_Success"
            case .appleAuthFail:    return "CreateAccountView_AppleAuth_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .appleAuthSuccess(let user, let isNewUser):
                var dict = user.eventParameters
                dict["is_new_user"] = isNewUser
                return dict
            case .appleAuthFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .appleAuthFail: return .severe
            default: return .analytic
            }
        }
    }

    func onSignInApplePressed() {
        interactor.trackEvent(event: Event.appleAuthStart)

        Task {
            do {
                let (user, isNewUser) = try await interactor.signInApple()
                interactor.trackEvent(event: Event.appleAuthSuccess(user: user, isNewUser: isNewUser))
                try await interactor.logIn(user: user, isNewUser: isNewUser)
            } catch {
                interactor.trackEvent(event: Event.appleAuthFail(error: error))
            }
        }
    }
}
```
