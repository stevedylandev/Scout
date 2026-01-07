//
//  ClientCertificateManager.swift
//  Titan
//
//  Manages client certificates for Gemini authentication
//

import Foundation
import Security
import CommonCrypto

// MARK: - Data Models

struct ClientCertificate: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let fingerprint: String
    let createdAt: Date
    let expiresAt: Date

    init(id: UUID = UUID(), name: String, fingerprint: String, createdAt: Date = Date(), expiresAt: Date) {
        self.id = id
        self.name = name
        self.fingerprint = fingerprint
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
    }
}

struct CertificateHostAssociation: Codable, Equatable, Identifiable {
    var id: String { "\(host):\(port)\(pathPrefix)" }
    let certificateId: UUID
    let host: String
    let port: Int
    let pathPrefix: String
    let createdAt: Date

    init(certificateId: UUID, host: String, port: Int = 1965, pathPrefix: String = "/", createdAt: Date = Date()) {
        self.certificateId = certificateId
        self.host = host
        self.port = port
        self.pathPrefix = pathPrefix
        self.createdAt = createdAt
    }
}

// MARK: - Errors

enum ClientCertificateError: LocalizedError {
    case generationFailed(Error)
    case keychainStoreFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    case identityNotFound
    case certificateCreationFailed

    var errorDescription: String? {
        switch self {
        case .generationFailed(let error):
            return "Certificate generation failed: \(error.localizedDescription)"
        case .keychainStoreFailed(let status):
            return "Failed to store in Keychain (status: \(status))"
        case .keychainDeleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        case .identityNotFound:
            return "Certificate identity not found in Keychain"
        case .certificateCreationFailed:
            return "Failed to create certificate from data"
        }
    }
}

// MARK: - Manager

@Observable
class ClientCertificateManager {
    private let certificatesStorageKey = "titan_client_certificates"
    private let associationsStorageKey = "titan_client_cert_associations"
    private let keychainTagPrefix = "com.titan.clientcert"

    var certificates: [ClientCertificate] = []
    var associations: [CertificateHostAssociation] = []

    init() {
        loadData()
        cleanupOrphanedAssociations()
    }

    // MARK: - Certificate Lifecycle

    /// Creates a new client certificate with the given friendly name
    func createCertificate(name: String, validityDays: Int = 365) throws -> ClientCertificate {
        // Generate the certificate
        let (certificateData, privateKey) = try X509Generator.generateSelfSignedCertificate(
            commonName: name,
            validityDays: validityDays
        )

        // Create SecCertificate from data
        guard let secCertificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            throw ClientCertificateError.certificateCreationFailed
        }

        let id = UUID()
        let fingerprint = CertificateManager.sha256Fingerprint(certificateData)
        let expiresAt = Calendar.current.date(byAdding: .day, value: validityDays, to: Date())!

        // Store in Keychain
        try storeInKeychain(
            id: id,
            certificate: secCertificate,
            privateKey: privateKey
        )

        // Create metadata
        let certificate = ClientCertificate(
            id: id,
            name: name,
            fingerprint: fingerprint,
            createdAt: Date(),
            expiresAt: expiresAt
        )

        certificates.append(certificate)
        saveData()

        print("🔐 Created client certificate: \(name)")
        return certificate
    }

    /// Deletes a certificate and all its associations
    func deleteCertificate(id: UUID) throws {
        // Remove from Keychain
        try deleteFromKeychain(id: id)

        // Remove metadata
        certificates.removeAll { $0.id == id }

        // Remove all associations
        associations.removeAll { $0.certificateId == id }

        saveData()
        print("🗑️ Deleted client certificate: \(id)")
    }

    /// Gets a certificate by ID
    func getCertificate(id: UUID) -> ClientCertificate? {
        certificates.first { $0.id == id }
    }

    // MARK: - Host Associations

    /// Associates a certificate with a URL (host + port + path prefix)
    func associateCertificate(certificateId: UUID, with url: URL) {
        let host = url.host ?? ""
        let port = url.port ?? 1965
        let pathPrefix = normalizePathPrefix(url.path)

        // Remove any existing association for this exact path
        associations.removeAll { $0.host == host && $0.port == port && $0.pathPrefix == pathPrefix }

        let association = CertificateHostAssociation(
            certificateId: certificateId,
            host: host,
            port: port,
            pathPrefix: pathPrefix
        )

        associations.append(association)
        saveData()

        print("🔗 Associated certificate with \(host):\(port)\(pathPrefix)")
    }

    /// Removes a specific association
    func removeAssociation(host: String, port: Int, pathPrefix: String) {
        associations.removeAll { $0.host == host && $0.port == port && $0.pathPrefix == pathPrefix }
        saveData()
    }

    /// Gets all associations for a certificate
    func getAssociationsForCertificate(id: UUID) -> [CertificateHostAssociation] {
        associations.filter { $0.certificateId == id }
    }

    /// Finds the best matching certificate for a URL
    /// Returns the SecIdentity if found, nil otherwise
    func findIdentity(for url: URL) -> SecIdentity? {
        guard let certificateId = findCertificateId(for: url) else {
            return nil
        }
        return getSecIdentity(for: certificateId)
    }

    /// Finds the certificate ID for a URL (longest path prefix match)
    func findCertificateId(for url: URL) -> UUID? {
        let host = url.host ?? ""
        let port = url.port ?? 1965
        let path = url.path.isEmpty ? "/" : url.path

        // Find all matching associations
        let matching = associations
            .filter { $0.host == host && $0.port == port }
            .filter { path.hasPrefix($0.pathPrefix) }
            .sorted { $0.pathPrefix.count > $1.pathPrefix.count }

        return matching.first?.certificateId
    }

    /// Checks if a URL has an associated certificate
    func hasAssociation(for url: URL) -> Bool {
        findCertificateId(for: url) != nil
    }

    // MARK: - Keychain Operations

    /// Retrieves SecIdentity from Keychain
    func getSecIdentity(for certificateId: UUID) -> SecIdentity? {
        let tag = keychainTag(for: certificateId)

        // First get the certificate
        let certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: tag,
            kSecReturnRef as String: true
        ]

        var certRef: CFTypeRef?
        let certStatus = SecItemCopyMatching(certQuery as CFDictionary, &certRef)

        guard certStatus == errSecSuccess, let certificate = certRef else {
            print("❌ Certificate not found in Keychain for \(certificateId)")
            return nil
        }

        // Then get the private key
        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        var keyRef: CFTypeRef?
        let keyStatus = SecItemCopyMatching(keyQuery as CFDictionary, &keyRef)

        guard keyStatus == errSecSuccess, let privateKey = keyRef else {
            print("❌ Private key not found in Keychain for \(certificateId)")
            return nil
        }

        // Create identity from certificate and key
        // Note: SecIdentityCreateWithCertificate is not available on iOS
        // We need to use a different approach - store as identity directly
        // or use SecPKCS12Import approach

        // For iOS, we'll return a constructed identity using our stored items
        // The Network framework's sec_identity_create can work with (cert, key) pairs
        // But we need SecIdentity for that API

        // Alternative: Query for identity directly (requires items to be stored as identity)
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: tag,
            kSecReturnRef as String: true
        ]

        var identityRef: CFTypeRef?
        let identityStatus = SecItemCopyMatching(identityQuery as CFDictionary, &identityRef)

        if identityStatus == errSecSuccess, let identity = identityRef {
            return (identity as! SecIdentity)
        }

        print("❌ Identity not found in Keychain for \(certificateId)")
        return nil
    }

    private func storeInKeychain(id: UUID, certificate: SecCertificate, privateKey: SecKey) throws {
        let tag = keychainTag(for: id)
        let tagData = tag.data(using: .utf8)!

        // First, store the private key
        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecValueRef as String: privateKey,
            kSecAttrIsPermanent as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrLabel as String: tag
        ]

        var keyStatus = SecItemAdd(keyQuery as CFDictionary, nil)
        if keyStatus == errSecDuplicateItem {
            // Delete and retry
            SecItemDelete(keyQuery as CFDictionary)
            keyStatus = SecItemAdd(keyQuery as CFDictionary, nil)
        }

        if keyStatus != errSecSuccess {
            throw ClientCertificateError.keychainStoreFailed(keyStatus)
        }

        // Then store the certificate
        let certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: tag,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        var certStatus = SecItemAdd(certQuery as CFDictionary, nil)
        if certStatus == errSecDuplicateItem {
            SecItemDelete(certQuery as CFDictionary)
            certStatus = SecItemAdd(certQuery as CFDictionary, nil)
        }

        if certStatus != errSecSuccess {
            // Clean up the key we just added
            SecItemDelete(keyQuery as CFDictionary)
            throw ClientCertificateError.keychainStoreFailed(certStatus)
        }

        // The identity should be automatically created by the Keychain
        // when a certificate and its matching private key are both stored
        print("✅ Stored certificate and key in Keychain with tag: \(tag)")
    }

    private func deleteFromKeychain(id: UUID) throws {
        let tag = keychainTag(for: id)
        let tagData = tag.data(using: .utf8)!

        // Delete certificate
        let certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: tag
        ]
        SecItemDelete(certQuery as CFDictionary)

        // Delete private key
        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData
        ]
        SecItemDelete(keyQuery as CFDictionary)

        // Delete identity (if exists)
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: tag
        ]
        SecItemDelete(identityQuery as CFDictionary)
    }

    private func keychainTag(for id: UUID) -> String {
        "\(keychainTagPrefix).\(id.uuidString)"
    }

    // MARK: - Persistence

    private func saveData() {
        if let certData = try? JSONEncoder().encode(certificates) {
            UserDefaults.standard.set(certData, forKey: certificatesStorageKey)
        }
        if let assocData = try? JSONEncoder().encode(associations) {
            UserDefaults.standard.set(assocData, forKey: associationsStorageKey)
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: certificatesStorageKey),
           let decoded = try? JSONDecoder().decode([ClientCertificate].self, from: data) {
            certificates = decoded
        }
        if let data = UserDefaults.standard.data(forKey: associationsStorageKey),
           let decoded = try? JSONDecoder().decode([CertificateHostAssociation].self, from: data) {
            associations = decoded
        }
    }

    private func cleanupOrphanedAssociations() {
        let validIds = Set(certificates.map { $0.id })
        let before = associations.count
        associations.removeAll { !validIds.contains($0.certificateId) }
        if associations.count != before {
            saveData()
            print("🧹 Cleaned up \(before - associations.count) orphaned associations")
        }
    }

    // MARK: - Helpers

    private func normalizePathPrefix(_ path: String) -> String {
        var normalized = path.isEmpty ? "/" : path
        // Remove trailing slash unless it's the root
        if normalized.count > 1 && normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }
}
