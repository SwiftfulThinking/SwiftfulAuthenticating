//
//  SignInOption.swift
//  SwiftfulAuthenticating
//
//  Created by Nick Sarno on 9/28/24.
//


public enum SignInOption: String, Sendable {
    case apple, google, anonymous
    
    var eventParameters: [String: Any] {
        ["sign_in_option": rawValue]
    }
}
