//
//  KeychainHelper.swift
//  traverse
//

import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    private let service = "com.traverse.app"
    private let tokenKey = "authToken"
    
    // Save token to Keychain
    func saveToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey
        ]
        let tokenAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(identityQuery as CFDictionary, tokenAttributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var insertQuery = identityQuery
        insertQuery[kSecValueData as String] = data
        insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(insertQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // Retrieve token from Keychain
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    // Delete token from Keychain
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
