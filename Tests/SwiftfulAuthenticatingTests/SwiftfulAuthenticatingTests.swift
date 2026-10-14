import Testing
import SwiftUI
import Foundation
@testable import SwiftfulAuthenticating

@MainActor
struct AuthManagerTests {

    @Test("AuthManager initializes with the provided authenticated user")
    func testInitializationWithAuthenticatedUser() async throws {
        // Given
        let uid = UUID().uuidString
        let name = UUID().uuidString
        let email = "\(UUID().uuidString)@example.com"
        
        let mockUser = UserAuthInfo(uid: uid, email: email, displayName: name)
        let authService = MockAuthService(user: mockUser)

        // When
        let authManager = AuthManager(service: authService)

        // Then
        #expect(authManager.auth?.uid == uid)
    }

    @Test("AuthManager initializes with nil auth if no user is authenticated")
    func testInitializationWithNoAuthenticatedUser() async throws {
        // Given
        let authService = MockAuthService()

        // When
        let authManager = AuthManager(service: authService)

        // Then
        #expect(authManager.auth == nil)
    }

    @Test("AuthManager signs in successfully and logs events")
    func testSignInSuccess() async throws {
        // Given
        
        let authService = MockAuthService()
        let authManager = AuthManager(service: authService)

        // When
        let result = try await authManager.signIn(option: .anonymous)

        // Then
        #expect(result.user.uid != nil)
    }

    @Test("AuthManager handles sign-in failure and logs the error")
    func testSignInFailure() async throws {
        // Fixme: mock isn't testable?
    }

    @Test("AuthManager signs out successfully and logs events")
    func testSignOut() async throws {
        // Given
        let authService = MockAuthService(user: UserAuthInfo.mock())
        let authManager = AuthManager(service: authService)

        // When
        try authManager.signOut()

        // Then
        #expect(authManager.auth == nil)
    }

    @Test("AuthManager deletes account successfully and logs events")
    func testDeleteAccount() async throws {
        // Given
        let authService = MockAuthService(user: UserAuthInfo.mock())
        let authManager = AuthManager(service: authService)

        // When
        try await authManager.deleteAccount()

        // Then
        #expect(authManager.auth == nil)
    }
}

@MainActor
struct AuthManagerReauthenticationTests {

    private func makeManager(user: UserAuthInfo?, store: InMemoryRealAccountMarkerStore = InMemoryRealAccountMarkerStore(), maxDeclines: Int = 2) -> (AuthManager, InMemoryRealAccountMarkerStore) {
        UserDefaults.standard.removeObject(forKey: "swiftful_auth_reauth_prompt_decline_count")
        let manager = AuthManager(
            service: MockAuthService(user: user),
            markerStore: store,
            reauthPromptPolicy: ReauthPromptPolicy(maxDeclines: maxDeclines, foregroundRepromptInterval: 0)
        )
        return (manager, store)
    }

    @Test("A real sign-in writes the marker; an anonymous session does not")
    func testMarkerWrittenOnRealSignIn() async throws {
        let (manager, store) = makeManager(user: nil)
        #expect(manager.hadPreviousRealAccount == false)

        try await manager.signIn(option: .apple)

        #expect(manager.hadPreviousRealAccount == true)
        #expect(manager.lastRealAccountUid == manager.auth?.uid)
        #expect(store.read(source: .thisDevice)?.uid == manager.auth?.uid)
        #expect(store.read(source: .anyDevice)?.uid == manager.auth?.uid)
    }

    @Test("A restored real session at init writes the marker (backfill)")
    func testMarkerBackfilledAtInit() async throws {
        let (manager, store) = makeManager(user: .mock(isAnonymous: false))
        #expect(manager.hadPreviousRealAccount == true)
        #expect(store.read(source: .thisDevice) != nil)
    }

    @Test("A restored anonymous session at init does not write the marker")
    func testNoMarkerForAnonymousAtInit() async throws {
        let (manager, _) = makeManager(user: .mock(isAnonymous: true))
        #expect(manager.hadPreviousRealAccount == false)
    }

    @Test("Explicit sign-out clears the marker, so no prompt follows")
    func testSignOutClearsMarker() async throws {
        let (manager, store) = makeManager(user: .mock(isAnonymous: false))
        try manager.signOut()
        #expect(manager.hadPreviousRealAccount == false)
        #expect(store.read(source: .thisDevice) == nil)
        #expect(store.read(source: .anyDevice) == nil)
        #expect(manager.shouldBlockAnonMintForReauthentication == false)
        #expect(manager.shouldPromptForReauthentication == false)
    }

    @Test("Delete account clears the marker")
    func testDeleteClearsMarker() async throws {
        let (manager, store) = makeManager(user: .mock(isAnonymous: false))
        try await manager.deleteAccount()
        #expect(store.read(source: .thisDevice) == nil)
        #expect(manager.shouldPromptForReauthentication == false)
    }

    @Test("No session + device-local marker blocks the anonymous mint and asks to prompt")
    func testLostSessionBlocksMintAndPrompts() async throws {
        let marker = RealAccountMarker(uid: "real_uid", provider: .apple)
        let store = InMemoryRealAccountMarkerStore(thisDevice: marker, anyDevice: marker)
        let (manager, _) = makeManager(user: nil, store: store)

        #expect(manager.shouldBlockAnonMintForReauthentication == true)
        #expect(manager.shouldPromptForReauthentication == true)
        #expect(manager.reauthPromptMarkerSource == .thisDevice)
        #expect(manager.lastSignInProvider == .apple)
    }

    @Test("New device: synced marker only prompts but does not block the first-launch mint")
    func testSyncedMarkerPromptsWithoutBlocking() async throws {
        let marker = RealAccountMarker(uid: "real_uid", provider: .google)
        let store = InMemoryRealAccountMarkerStore(thisDevice: nil, anyDevice: marker)
        let (manager, _) = makeManager(user: nil, store: store)

        #expect(manager.shouldBlockAnonMintForReauthentication == false)
        #expect(manager.shouldPromptForReauthentication == true)
        #expect(manager.reauthPromptMarkerSource == .anyDevice)
    }

    @Test("Declines spend the budget; exhausting it stops both the block and the prompt")
    func testDeclineBudget() async throws {
        let marker = RealAccountMarker(uid: "real_uid", provider: .apple)
        let store = InMemoryRealAccountMarkerStore(thisDevice: marker, anyDevice: marker)
        let (manager, _) = makeManager(user: nil, store: store, maxDeclines: 2)

        manager.recordReauthPromptDeclined()
        #expect(manager.reauthPromptDeclineCount == 1)
        #expect(manager.shouldPromptForReauthentication == true)

        manager.recordReauthPromptDeclined()
        #expect(manager.shouldBlockAnonMintForReauthentication == false)
        #expect(manager.shouldPromptForReauthentication == false)
    }

    @Test("The anonymous account minted after a decline still prompts on later launches")
    func testAnonymousWithMarkerStillPrompts() async throws {
        let marker = RealAccountMarker(uid: "real_uid", provider: .apple)
        let store = InMemoryRealAccountMarkerStore(thisDevice: marker, anyDevice: marker)
        let (manager, _) = makeManager(user: .mock(isAnonymous: true), store: store)

        #expect(manager.shouldBlockAnonMintForReauthentication == false) // there IS a session
        #expect(manager.shouldPromptForReauthentication == true)
    }

    @Test("A real sign-in resets the decline budget")
    func testRealSignInResetsBudget() async throws {
        let marker = RealAccountMarker(uid: "real_uid", provider: .apple)
        let store = InMemoryRealAccountMarkerStore(thisDevice: marker, anyDevice: marker)
        let (manager, _) = makeManager(user: nil, store: store)
        manager.recordReauthPromptDeclined()

        try await manager.signIn(option: .apple)

        #expect(manager.reauthPromptDeclineCount == 0)
        #expect(manager.shouldPromptForReauthentication == false)
    }
}
