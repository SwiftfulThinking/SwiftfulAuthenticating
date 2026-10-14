//
//  RealAccountMarkerStore.swift
//  SwiftfulAuthenticating
//
//  Created by Nick Sarno on 10/8/26.
//
import Foundation
import Security

/// Persists the `RealAccountMarker` in two places: a device-local slot (survives reinstall on the same
/// device, mirrors Firebase Auth's own keychain accessibility) and an iCloud-synced slot (survives new device).
@MainActor
public protocol RealAccountMarkerStore {
    func read(source: RealAccountMarkerSource) -> RealAccountMarker?
    func write(_ marker: RealAccountMarker)
    func clear()
}

/// Keychain-backed store (generic-password items, no third-party dependency).
@MainActor
public struct KeychainRealAccountMarkerStore: RealAccountMarkerStore {
    private let service: String
    private let key = "real_account_marker"

    public init(service: String = (Bundle.main.bundleIdentifier ?? "swiftful") + ".swiftfulauthenticating.marker") {
        self.service = service
    }

    public func read(source: RealAccountMarkerSource) -> RealAccountMarker? {
        guard let data = KeychainItem(service: service, key: key, source: source).read() else { return nil }
        return try? JSONDecoder().decode(RealAccountMarker.self, from: data)
    }

    public func write(_ marker: RealAccountMarker) {
        guard let data = try? JSONEncoder().encode(marker) else { return }
        KeychainItem(service: service, key: key, source: .thisDevice).write(data)
        KeychainItem(service: service, key: key, source: .anyDevice).write(data)
    }

    public func clear() {
        KeychainItem(service: service, key: key, source: .thisDevice).delete()
        KeychainItem(service: service, key: key, source: .anyDevice).delete()
    }
}

/// In-memory store for previews and tests.
@MainActor
public final class InMemoryRealAccountMarkerStore: RealAccountMarkerStore {
    private var thisDevice: RealAccountMarker?
    private var anyDevice: RealAccountMarker?

    public init(thisDevice: RealAccountMarker? = nil, anyDevice: RealAccountMarker? = nil) {
        self.thisDevice = thisDevice
        self.anyDevice = anyDevice
    }

    public func read(source: RealAccountMarkerSource) -> RealAccountMarker? {
        source == .thisDevice ? thisDevice : anyDevice
    }

    public func write(_ marker: RealAccountMarker) {
        thisDevice = marker
        anyDevice = marker
    }

    public func clear() {
        thisDevice = nil
        anyDevice = nil
    }
}

private struct KeychainItem {
    let service: String
    let key: String
    let source: RealAccountMarkerSource

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: source == .anyDevice
        ]
    }

    private var accessibility: CFString {
        // Synced items cannot be ThisDeviceOnly; local mirrors Firebase Auth (readable after first unlock).
        source == .anyDevice ? kSecAttrAccessibleAfterFirstUnlock : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    }

    func read() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func write(_ data: Data) {
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = accessibility
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: accessibility
            ]
            SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        }
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
