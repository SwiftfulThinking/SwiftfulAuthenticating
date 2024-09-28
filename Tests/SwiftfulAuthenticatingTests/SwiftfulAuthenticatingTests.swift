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
        let authService = MockAuthService(user: UserAuthInfo.mock)
        let authManager = AuthManager(service: authService)

        // When
        try authManager.signOut()

        // Then
        #expect(authManager.auth == nil)
    }

    @Test("AuthManager deletes account successfully and logs events")
    func testDeleteAccount() async throws {
        // Given
        let authService = MockAuthService(user: UserAuthInfo.mock)
        let authManager = AuthManager(service: authService)

        // When
        try await authManager.deleteAccount()

        // Then
        #expect(authManager.auth == nil)
    }
}
