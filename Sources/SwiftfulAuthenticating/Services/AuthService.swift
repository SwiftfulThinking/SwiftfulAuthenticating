import SwiftUI

@MainActor
public protocol AuthService: Sendable {
    func getAuthenticatedUser() -> UserAuthInfo?
    func addAuthenticatedUserListener() -> AsyncStream<UserAuthInfo?>
    func signIn(option: SignInOption) async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func signOut() throws
    func deleteAccount() async throws
    func deleteAccountWithReauthentication(option: SignInOption, revokeToken: Bool, performDeleteActionsBeforeAuthIsDeleted: () async throws -> Void) async throws
}
