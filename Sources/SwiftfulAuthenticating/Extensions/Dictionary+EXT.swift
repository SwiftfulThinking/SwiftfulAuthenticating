//
//  File.swift
//  SwiftfulAuthenticating
//
//  Created by Nick Sarno on 9/28/24.
//
import Foundation

extension Dictionary {
    mutating func merge(_ other: Dictionary?) {
        if let other {
            for (key, value) in other {
                self[key] = value
            }
        }
    }
}
