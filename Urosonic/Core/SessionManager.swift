// SessionManager.swift — Clinical User Session & Security Manager
// Handles user session persistence, automatic restore, keychain token storage, and session lifecycles.

import Foundation
import Combine
import SwiftUI
import Security

// MARK: - Notification Extensions for Session Events
extension Notification.Name {
    static let userSessionDidStart  = Notification.Name("userSessionDidStart")
    static let userSessionDidEnd    = Notification.Name("userSessionDidEnd")
    static let userSessionDidExpire = Notification.Name("userSessionDidExpire")
}

// MARK: - Lightweight Keychain Helper
final class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.saveetha.Urosonic.session"

    private init() {}

    func save(key: String, data: Data) -> Bool {
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  kCFBooleanTrue as Any,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        return status == errSecSuccess ? (dataTypeRef as? Data) : nil
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Session Metadata
struct SessionMetadata: Codable {
    let createdAt: Date
    var lastActiveAt: Date
    let userId: Int
    let userRole: String
    let email: String
}

// MARK: - Session Manager
@MainActor
final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    // Keys
    private let sessionUserKey     = "urosonic_session_user_profile"
    private let sessionMetaKey     = "urosonic_session_meta"
    private let keychainTokenKey   = "auth_token_key"
    private let keychainUserKey    = "auth_user_key"

    // In-memory active session
    @Published private(set) var activeUser: APIUser? = nil
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var lastActiveDate: Date? = nil

    /// Inactivity timeout: 30 days for clinical convenience
    private let sessionTimeoutInterval: TimeInterval = 30 * 24 * 60 * 60

    private init() {
        _ = restoreSession()
    }

    // MARK: - Session Validation
    var hasActiveSession: Bool {
        return activeUser != nil && isSessionValid()
    }

    var currentUserId: Int? {
        return activeUser?.id
    }

    var currentUserRole: String? {
        return activeUser?.role
    }

    // MARK: - Start Session
    /// Saves the authenticated user and optional token into storage and memory.
    func startSession(user: APIUser, token: String? = nil) {
        self.activeUser = user
        self.isAuthenticated = true
        self.lastActiveDate = Date()

        // 1. Store Token in Keychain (if provided or generate dummy bearer)
        if let token = token, let tokenData = token.data(using: .utf8) {
            _ = KeychainManager.shared.save(key: keychainTokenKey, data: tokenData)
        }

        // 2. Encode and store User Profile in Keychain as backup and UserDefaults
        if let userData = try? JSONEncoder().encode(user) {
            _ = KeychainManager.shared.save(key: keychainUserKey, data: userData)
            UserDefaults.standard.set(userData, forKey: sessionUserKey)
        }

        // 3. Store Session Metadata
        let meta = SessionMetadata(
            createdAt: Date(),
            lastActiveAt: Date(),
            userId: user.id,
            userRole: user.role,
            email: user.email
        )
        if let metaData = try? JSONEncoder().encode(meta) {
            UserDefaults.standard.set(metaData, forKey: sessionMetaKey)
        }

        NotificationCenter.default.post(name: .userSessionDidStart, object: user)
    }

    // MARK: - Restore Session
    /// Attempts to restore user session from storage. Returns the active user if valid.
    @discardableResult
    func restoreSession() -> APIUser? {
        // Check metadata first
        guard let metaData = UserDefaults.standard.data(forKey: sessionMetaKey),
              let meta = try? JSONDecoder().decode(SessionMetadata.self, from: metaData) else {
            clearSessionData()
            return nil
        }

        // Check expiration
        let elapsed = Date().timeIntervalSince(meta.lastActiveAt)
        if elapsed > sessionTimeoutInterval {
            clearSessionData()
            NotificationCenter.default.post(name: .userSessionDidExpire, object: nil)
            return nil
        }

        // Load user data (first try UserDefaults, fallback to Keychain)
        var restoredUser: APIUser? = nil
        if let userData = UserDefaults.standard.data(forKey: sessionUserKey),
           let user = try? JSONDecoder().decode(APIUser.self, from: userData) {
            restoredUser = user
        } else if let kcData = KeychainManager.shared.load(key: keychainUserKey),
                  let user = try? JSONDecoder().decode(APIUser.self, from: kcData) {
            restoredUser = user
        }

        guard let user = restoredUser else {
            clearSessionData()
            return nil
        }

        self.activeUser = user
        self.isAuthenticated = true
        self.lastActiveDate = meta.lastActiveAt

        // Touch session activity
        touchSession()

        return user
    }

    // MARK: - Refresh Profile from Backend
    /// Fetches the latest user profile from the server to keep condition/doctor/credentials up-to-date.
    func refreshSessionProfile() async throws -> APIUser {
        guard let userId = activeUser?.id else {
            throw APIError.noData
        }
        let freshUser = try await APIClient.shared.getProfile(userId: userId)
        startSession(user: freshUser, token: getAuthToken())
        return freshUser
    }

    // MARK: - Touch Session (Update activity timestamp)
    func touchSession() {
        guard var metaData = UserDefaults.standard.data(forKey: sessionMetaKey),
              var meta = try? JSONDecoder().decode(SessionMetadata.self, from: metaData) else { return }

        meta.lastActiveAt = Date()
        self.lastActiveDate = meta.lastActiveAt
        if let updatedData = try? JSONEncoder().encode(meta) {
            UserDefaults.standard.set(updatedData, forKey: sessionMetaKey)
        }
    }

    // MARK: - End Session / Logout
    func endSession() {
        clearSessionData()
        NotificationCenter.default.post(name: .userSessionDidEnd, object: nil)
    }

    private func clearSessionData() {
        self.activeUser = nil
        self.isAuthenticated = false
        self.lastActiveDate = nil

        UserDefaults.standard.removeObject(forKey: sessionUserKey)
        UserDefaults.standard.removeObject(forKey: sessionMetaKey)
        KeychainManager.shared.delete(key: keychainTokenKey)
        KeychainManager.shared.delete(key: keychainUserKey)
    }

    // MARK: - Helper Getters
    func getAuthToken() -> String? {
        guard let data = KeychainManager.shared.load(key: keychainTokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func isSessionValid() -> Bool {
        guard let metaData = UserDefaults.standard.data(forKey: sessionMetaKey),
              let meta = try? JSONDecoder().decode(SessionMetadata.self, from: metaData) else {
            return false
        }
        return Date().timeIntervalSince(meta.lastActiveAt) <= sessionTimeoutInterval
    }
}
