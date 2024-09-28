//
//  Error+EXT.swift
//  SwiftfulAuthenticating
//
//  Created by Nick Sarno on 9/28/24.
//


import Foundation

extension Error {
    var eventParameters: [String: Any] {
        [
            "error_description": self.localizedDescription
        ]
    }
}