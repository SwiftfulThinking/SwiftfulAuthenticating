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
    public let firstName: String?
    public let lastName: String?
    public let phoneNumber: String?
    public let photoURL: URL?
    public let creationDate: Date?
    public let lastSignInDate: Date?
    
    public var name: String? {
        if let displayName {
            return displayName
        }
        
        if let firstName, let lastName {
            return firstName + " " + lastName
        } else if let firstName {
            return firstName
        }
        
        return lastName
    }

    public init(
        uid: String,
        email: String? = nil,
        isAnonymous: Bool = false,
        authProviders: [AuthProviderOption] = [],
        displayName: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
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
        self.firstName = firstName
        self.lastName = lastName
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
        case firstName = "first_name"
        case lastName = "last_name"
        case phoneNumber = "phone_number"
        case photoURL = "photo_url"
        case creationDate = "creation_date"
        case lastSignInDate = "last_sign_in_date"
    }

    static func mock(isAnonymous: Bool = false) -> Self {
        UserAuthInfo(
            uid: "mock_user_123",
            email: "hello@gmail.com",
            isAnonymous: isAnonymous,
            authProviders: isAnonymous ? [] : [.apple],
            displayName: "Joe",
            phoneNumber: nil,
            photoURL: nil,
            creationDate: .now,
            lastSignInDate: .now
        )
    }

    public var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "uauth_\(CodingKeys.uid.rawValue)": uid,
            "uauth_\(CodingKeys.email.rawValue)": email,
            "uauth_\(CodingKeys.isAnonymous.rawValue)": isAnonymous,
            "uauth_\(CodingKeys.authProviders.rawValue)": authProviders.map({ $0.rawValue }).sorted().joined(separator: ", "),
            "uauth_\(CodingKeys.displayName.rawValue)": displayName,
            "uauth_\(CodingKeys.firstName.rawValue)": firstName,
            "uauth_\(CodingKeys.lastName.rawValue)": lastName,
            "uauth_name": name,
            "uauth_\(CodingKeys.phoneNumber.rawValue)": phoneNumber,
            "uauth_\(CodingKeys.photoURL.rawValue)": photoURL,
            "uauth_\(CodingKeys.creationDate.rawValue)": creationDate,
            "uauth_\(CodingKeys.lastSignInDate.rawValue)": lastSignInDate
        ]
        return dict.compactMapValues({ $0 })
    }
}
