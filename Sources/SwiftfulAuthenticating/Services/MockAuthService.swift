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
            Task {
                for await value in $currentUser.values {
                    continuation.yield(value)
                }
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

    public func deleteAccount(option: SignInOption, performDeleteActionsBeforeAuthIsRevoked: () async throws -> Void) async throws {
        try await performDeleteActionsBeforeAuthIsRevoked()
        currentUser = nil
    }

}
