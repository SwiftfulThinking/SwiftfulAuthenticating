//
//  AuthProviderOption.swift
//  SwiftfulAuthenticating
//
//  Created by Nick Sarno on 9/28/24.
//

import Foundation

public enum AuthProviderOption: String, Codable, Sendable {
    case google
    case apple
    case email

    var providerId: String {
        switch self {
        case .google:       return "google.com"
        case .apple:        return "apple.com"
        case .email:        return "password"
//        case .phone:        return "phone"
//        case .facebook:     return "facebook.com"
//        case .gameCenter:   return "gc.apple.com"
//        case .github:       return "github.com"
        }
    }

}
