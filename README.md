### 🚀 Learn how to build and use this package: https://www.swiftful-thinking.com/offers/REyNLwwH

# Authentication Manager for Swift 6 📝

A reusable AuthManager for Swift applications, built for Swift 6. Includes `@Observable` support.

![Platform: iOS/macOS](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-blue)

Pre-built dependencies*:

- Mock: Included
- Firebase: https://github.com/SwiftfulThinking/SwiftfulAuthenticatingFirebase

\* Created another? Send the url in [issues](https://github.com/SwiftfulThinking/SwiftfulAuthenticating/issues)! 🥳

- ✅ Sign In Apple
- ✅ Sign In Google
- ✅ Sign In Anonymous

```swift
Task {
     do {
          let (userAuthInfo, isNewUser) = try await authManager.signInApple()
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
    
#### Create an instance of AuthManager:

```swift
let authManager = AuthManager(services: any AuthService, logger: LogManager?)

#if DEBUG
let authManager = AuthManager(service: MockAuthService(), logger: logManager)
#else
let authManager = AuthManager(service: FirebaseAuthService(), logger: logManager)
#endif
```

#### Optionally add to SwiftUI environment as an @Observable

```swift
Text("Hello, world!")
    .environment(authManager)
```

</details>

## Inject dependencies

<details>
<summary> Details (Click to expand) </summary>
<br>
    
`AuthManager` is initialized with a `AuthService`. This is a public protocol you can use to create your own dependency.

`MockPurchaseService` is included for SwiftUI previews and testing. 

```swift
// User is not yet authenticated
let service = MockAuthService(user: nil)

// User is already authenticated
let service = MockAuthService(user: .mock)
```

Other services are not directly included, so that the developer can pick-and-choose which dependencies to add to the project. 

You can create your own `AuthService` by conforming to the protocol:

```swift
public protocol AuthService: Sendable {
    func getAuthenticatedUser() -> UserAuthInfo?
    func addAuthenticatedUserListener() -> AsyncStream<UserAuthInfo?>
    func signIn(option: SignInOption) async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func signOut() throws
    func deleteAccount() async throws
}
```

</details>

## Manage user account

<details>
<summary> Details (Click to expand) </summary>
<br>
    
The manager will automatically fetch and listen for an authenticated user on launch, via `getAuthenticatedUser` and `addAuthenticatedUserListener`.

### Get authenticated user's info:
```swift
let userId = authManager.auth.uid
let authUser = authManager.auth

// Throwing method for convenience with async/await
let uid = try authManager.getAuthId()
```

### Sign out:
```swift
try authManager.signOut()
```

### Delete account:

#### To immediately delete the user's authentication:
```swift
try await authManager.deleteAccount()
```

#### To first reauthenticate user and then revoke their token:
```swift
try await service.deleteAccountWithReauthentication(option: option, revokeToken: revokeToken, performDeleteActionsBeforeAuthIsDeleted: {
    // Perform final actions after reauthentication but before account deletion
    // ie. delete user's firestore data before they lost auth access through security rules
})
```

#### NOTE: If you choose to revoke the user's Apple SSO token, you MUST do additional setup in Firebase:

* Firebase -> Authentication -> Sign-in Method -> Apple ->
  * Add Services ID 
    * https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web
  * Add OAuth code flow (Apple team ID, Key ID and Private Key)
    * https://developer.apple.com/help/account/keys/create-a-private-key

</details>

## Sign In Apple

<details>
<summary> Details (Click to expand) </summary>
<br>

### Add Sign in with Apple Signing Capability to your Xcode project.
* Xcode Project Navigator -> Target -> Signing & Capabilities -> + Capability -> Sign in with Apple (requires Apple Developer Account)

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

### Update your app's the info.plist file.
* Firebase Console -> Project Settings -> Your apps -> GoogleService-Info.plist

### Add custom URL scheme (URL Types -> REVERSED_CLIENT_ID)
* GoogleService-Info.plist -> REVERSED_CLIENT_ID
* Xcode Project Navigator -> Target -> Info -> URL Types -> add REVERSED_CLIENT_ID as URL Schemes value

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

## Sign In Anonymous / Mock

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
try await authManager.signInAnonymous()
```

</details>
