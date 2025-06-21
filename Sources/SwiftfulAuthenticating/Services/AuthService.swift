import SwiftUI

@MainActor
public protocol AuthService: Sendable {
    func getAuthenticatedUser() -> UserAuthInfo?
    func addAuthenticatedUserListener() -> AsyncStream<UserAuthInfo?>
    func signIn(option: SignInOption) async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func signOut() throws
    func deleteAccount(option: SignInOption) async throws
}
