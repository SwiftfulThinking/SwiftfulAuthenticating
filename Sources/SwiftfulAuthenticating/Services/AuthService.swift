import SwiftUI

@MainActor
public protocol AuthService: Sendable {
    func getAuthenticatedUser() -> UserAuthInfo?
    func addAuthenticatedUserListener(onListenerAttached: (any NSObjectProtocol) -> Void) -> AsyncStream<UserAuthInfo?>
    func signIn(option: SignInOption) async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func signOut() throws
    func deleteAccount() async throws
}
