//
//  RealAccountMarker.swift
//  SwiftfulAuthenticating
//
//  Created by Nick Sarno on 10/8/26.
//
import Foundation

/// Proof that this device (or this iCloud identity) once authenticated as a REAL (non-anonymous) account.
///
/// Written to the keychain on every real sign-in and cleared on explicit sign-out / delete, so the only way
/// to be signed out (or anonymous) WITH a marker present is that a real session was lost out from under
/// the user — password reset, credential change, provider takeover, reinstall. See `AuthManager.hadPreviousRealAccount`.
public struct RealAccountMarker: Codable, Sendable, Equatable {
    public let uid: String
    public let provider: AuthProviderOption?
    public let timestamp: TimeInterval
    public let appVersion: String?

    public init(uid: String, provider: AuthProviderOption?, timestamp: TimeInterval = Date().timeIntervalSince1970, appVersion: String? = RealAccountMarker.currentAppVersion) {
        self.uid = uid
        self.provider = provider
        self.timestamp = timestamp
        self.appVersion = appVersion
    }

    public static var currentAppVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    public var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "marker_uid": uid,
            "marker_provider": provider?.rawValue,
            "marker_timestamp": timestamp,
            "marker_app_version": appVersion
        ]
        return dict.compactMapValues({ $0 })
    }
}

/// Where a marker was read from.
public enum RealAccountMarkerSource: String, Sendable {
    /// Device-local keychain: the SAME install (or a reinstall on the same device) had a real account.
    case thisDevice
    /// iCloud-synced keychain: this iCloud identity had a real account somewhere (new device / reinstall).
    case anyDevice
}
