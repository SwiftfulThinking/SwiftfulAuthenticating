//
//  UserAuthInfo.swift
//  SwiftfulAuthenticating
//
//  Created by Nick Sarno on 9/28/24.
//
import Foundation

public struct UserAuthInfo: Codable, Sendable {
    public let uid: String
    public let email: String?
    public let isAnonymous: Bool
    public let authProviders: [AuthProviderOption]
    public let displayName: String?
    public let phoneNumber: String?
    public let photoURL: URL?
    public let creationDate: Date?
    public let lastSignInDate: Date?

    public init(
        uid: String,
        email: String? = nil,
        isAnonymous: Bool = false,
        authProviders: [AuthProviderOption] = [],
        displayName: String? = nil,
        phoneNumber: String? = nil,
        photoURL: URL? = nil,
        creationDate: Date? = nil,
        lastSignInDate: Date? = nil
    ) {
        self.uid = uid
        self.email = email
        self.isAnonymous = isAnonymous
        self.authProviders = authProviders
        self.displayName = displayName
        self.phoneNumber = phoneNumber
        self.photoURL = photoURL
        self.creationDate = creationDate
        self.lastSignInDate = lastSignInDate
    }

    public enum CodingKeys: String, CodingKey {
        case uid = "user_id"
        case email = "email"
        case isAnonymous = "is_anonymous"
        case authProviders = "auth_providers"
        case displayName = "display_name"
        case phoneNumber = "phone_number"
        case photoURL = "photo_url"
        case creationDate = "creation_date"
        case lastSignInDate = "last_sign_in_date"
    }

    public static var mock: UserAuthInfo {
        UserAuthInfo(
            uid: "mock123",
            email: "hello@gmail.com",
            isAnonymous: false,
            authProviders: [.apple],
            displayName: "Nick",
            phoneNumber: nil,
            photoURL: nil,
            creationDate: .now,
            lastSignInDate: .now
        )
    }

    public static var mockAnonymous: UserAuthInfo {
        UserAuthInfo(
            uid: "anon123",
            email: "hello@gmail.com",
            isAnonymous: true,
            authProviders: [.apple],
            displayName: "Nick",
            phoneNumber: nil,
            photoURL: nil,
            creationDate: .now,
            lastSignInDate: .now
        )
    }

    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "uauth_\(CodingKeys.uid.rawValue)": uid,
            "uauth_\(CodingKeys.email.rawValue)": email,
            "uauth_\(CodingKeys.isAnonymous.rawValue)": isAnonymous,
            "uauth_\(CodingKeys.authProviders.rawValue)": authProviders.map({ $0.rawValue }).sorted().joined(separator: ", "),
            "uauth_\(CodingKeys.displayName.rawValue)": displayName,
            "uauth_\(CodingKeys.phoneNumber.rawValue)": phoneNumber,
            "uauth_\(CodingKeys.photoURL.rawValue)": photoURL,
            "uauth_\(CodingKeys.creationDate.rawValue)": creationDate,
            "uauth_\(CodingKeys.lastSignInDate.rawValue)": lastSignInDate
        ]
        return dict.compactMapValues({ $0 })
    }
}
