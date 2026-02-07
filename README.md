# SwiftfulAuthenticating

A reusable AuthManager for Swift applications, built for Swift 6. `AuthManager` wraps an `AuthService` implementation (Mock, Firebase, etc.) through a single API. Includes `@Observable` support.

- Sign In Apple
- Sign In Google
- Sign In Anonymous

```swift
Task {
    do {
        let (user, isNewUser) = try await authManager.signInApple()
        // User is signed in

        if isNewUser {
            // New user -> Create user profile in Firestore
        } else {
            // Existing user -> sign in
        }
    } catch {
        // User auth failed
    }
}
```

## Setup

<details>
<summary> Details (Click to expand) </summary>
<br>

Add SwiftfulAuthenticating to your project.

```
https://github.com/SwiftfulThinking/SwiftfulAuthenticating.git
```

Import the package.

```swift
import SwiftfulAuthenticating
```

Create an instance of `AuthManager` with an `AuthService`:

```swift
#if DEBUG
let authManager = AuthManager(service: MockAuthService(), logger: logManager)
#else
let authManager = AuthManager(service: FirebaseAuthService(), logger: logManager)
#endif
```

Optionally add to the SwiftUI environment:

```swift
Text("Hello, world!")
    .environment(authManager)
```

</details>

## Services

<details>
<summary> Details (Click to expand) </summary>
<br>

`AuthManager` is initialized with an `AuthService`. This is a public protocol you can use to create your own dependency.

Pre-built implementations:

- **Mock** — included, for SwiftUI previews and testing
- **Firebase** — [SwiftfulAuthenticatingFirebase](https://github.com/SwiftfulThinking/SwiftfulAuthenticatingFirebase)

`MockAuthService` is included for SwiftUI previews and testing:

```swift
// User is not yet authenticated
let service = MockAuthService(user: nil)

// User is already authenticated
let service = MockAuthService(user: .mock())
```

You can create your own `AuthService` by conforming to the protocol:

```swift
public protocol AuthService: Sendable {
    func getAuthenticatedUser() -> UserAuthInfo?
    func addAuthenticatedUserListener() -> AsyncStream<UserAuthInfo?>
    func signIn(option: SignInOption) async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func signOut() throws
    func deleteAccount() async throws
    func deleteAccountWithReauthentication(option: SignInOption, revokeToken: Bool, performDeleteActionsBeforeAuthIsDeleted: () async throws -> Void) async throws
}
```

</details>

## Manage User Account

<details>
<summary> Details (Click to expand) </summary>
<br>

The manager automatically fetches and listens for an authenticated user on launch, via `getAuthenticatedUser` and `addAuthenticatedUserListener`.

### Get authenticated user's info

```swift
let authUser = authManager.auth  // UserAuthInfo?
let userId = authManager.auth?.uid

// Throwing method for convenience with async/await
let uid = try authManager.getAuthId()
```

### Sign out

```swift
try authManager.signOut()
```

### Delete account

To immediately delete the user's authentication:

```swift
try await authManager.deleteAccount()
```

To first reauthenticate the user and then revoke their token:

```swift
try await authManager.deleteAccountWithReauthentication(option: option, revokeToken: revokeToken, performDeleteActionsBeforeAuthIsDeleted: {
    // Perform final actions after reauthentication but before account deletion
    // e.g. delete user's Firestore data before they lose auth access through security rules
})
```

**Note:** If you choose to revoke the user's Apple SSO token, you MUST do additional setup in Firebase:

- Firebase -> Authentication -> Sign-in Method -> Apple ->
  - Add Services ID
    - https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web
  - Add OAuth code flow (Apple team ID, Key ID and Private Key)
    - https://developer.apple.com/help/account/keys/create-a-private-key

</details>

## Sign In Apple

<details>
<summary> Details (Click to expand) </summary>
<br>

### Add Sign in with Apple Signing Capability to your Xcode project

- Xcode Project Navigator -> Target -> Signing & Capabilities -> + Capability -> Sign in with Apple (requires Apple Developer Account)

### Add Apple Button (optional), via SwiftfulAuthUI library

```swift
import SwiftfulAuthUI

SignInAppleButtonView()
    .frame(height: 50)
```

### Sign in

```swift
try await authManager.signInApple()
```

</details>

## Sign In Google

<details>
<summary> Details (Click to expand) </summary>
<br>

### Update your app's Info.plist file

- Firebase Console -> Project Settings -> Your apps -> GoogleService-Info.plist

### Add custom URL scheme (URL Types -> REVERSED_CLIENT_ID)

- GoogleService-Info.plist -> REVERSED_CLIENT_ID
- Xcode Project Navigator -> Target -> Info -> URL Types -> add REVERSED_CLIENT_ID as URL Schemes value

### Add Google Button (optional), via SwiftfulAuthUI library

```swift
import SwiftfulAuthUI

SignInGoogleButtonView()
    .frame(height: 50)
```

### Sign in

```swift
try await authManager.signInGoogle(GIDClientID: clientId)
```

</details>

## Sign In Anonymous

<details>
<summary> Details (Click to expand) </summary>
<br>

### Add Anonymous Button (optional), via SwiftfulAuthUI library

```swift
import SwiftfulAuthUI

SignInAnonymousButtonView()
    .frame(height: 50)
```

### Sign in

```swift
try await authManager.signInAnonymously()
```

</details>

## Claude Code

This package includes a `.claude/swiftful-authenticating-rules.md` with usage guidelines, auth flow patterns, and integration advice for projects using [Claude Code](https://claude.ai/claude-code).

## Platform Support

- **iOS 17.0+**
- **macOS 14.0+**

## License

SwiftfulAuthenticating is available under the MIT license.
