//
//  MockAuthService.swift
//  SwiftfulAuthenticating
//
//  Created by Nick Sarno on 9/28/24.
//
import SwiftUI

@MainActor
public class MockAuthService: AuthService {
    @Published private(set) var currentUser: UserAuthInfo?

    public init(user: UserAuthInfo? = nil) {
        self.currentUser = user
    }

    public func getAuthenticatedUser() -> UserAuthInfo? {
        currentUser
    }

    public func addAuthenticatedUserListener() -> AsyncStream<UserAuthInfo?> {
        AsyncStream { continuation in
            let task = Task {
                for await value in $currentUser.values {
                    continuation.yield(value)
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    public func removeAuthenticatedUserListener() {
        
    }

    public func signOut() throws {
        currentUser = nil
    }

    public func signIn(option: SignInOption) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        switch option {
        case .apple, .google, .anonymous:
            let user = UserAuthInfo.mock(isAnonymous: false)
            currentUser = user
            return (user, false)
        }
    }
    
    public func deleteAccount() async throws {
        currentUser = nil
    }

    public func deleteAccountWithReauthentication(option: SignInOption, revokeToken: Bool, performDeleteActionsBeforeAuthIsDeleted: () async throws -> Void) async throws {
        try await performDeleteActionsBeforeAuthIsDeleted()
        currentUser = nil
    }

}
