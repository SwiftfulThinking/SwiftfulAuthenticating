//
//  SignInOption.swift
//  SwiftfulAuthenticating
//
//  Created by Nick Sarno on 9/28/24.
//


public enum SignInOption: Sendable {
    case apple, anonymous
    case google(GIDClientID: String)
    
    public var stringValue: String {
        switch self {
        case .apple:
            return "apple"
        case .anonymous:
            return "anonymous"
        case .google:
            return "google"
        }
    }
    
    var eventParameters: [String: Any] {
        ["sign_in_option": stringValue]
    }
}
