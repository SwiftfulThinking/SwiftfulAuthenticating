//
//  AuthProviderOption.swift
//  SwiftfulAuthenticating
//
//  Created by Nick Sarno on 9/28/24.
//

import Foundation

public enum AuthProviderOption: String, Codable, Sendable, CaseIterable {
    case google
    case apple
    case email
    case phone
    case facebook
    case gameCenter
    case github
    
    public init?(providerId: String) {
        if let value = AuthProviderOption.allCases.first(where: { $0.providerId == providerId }) {
            self = value
        } else {
            return nil
        }
    }

    var providerId: String {
        switch self {
        case .google:       return "google.com"
        case .apple:        return "apple.com"
        case .email:        return "password"
        case .phone:        return "phone"
        case .facebook:     return "facebook.com"
        case .gameCenter:   return "gc.apple.com"
        case .github:       return "github.com"
        }
    }

}
