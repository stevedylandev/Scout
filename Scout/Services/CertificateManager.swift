//
//  CertificateManager.swift
//  Scout
//

import Foundation
import CommonCrypto
import Security

struct StoredCertificate: Identifiable, Codable, Equatable {
    let id: UUID
    let hostname: String
    let fingerprint: String
    let commonName: String
    let firstSeen: Date
    var lastSeen: Date

    init(id: UUID = UUID(), hostname: String, fingerprint: String, commonName: String, firstSeen: Date = Date(), lastSeen: Date = Date()) {
        self.id = id
        self.hostname = hostname
        self.fingerprint = fingerprint
        self.commonName = commonName
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
    }
}

@Observable
class CertificateManager {
    private let storageKey = "titan_certificates"

    var certificates: [StoredCertificate] = []

    init() {
        loadCertificates()
    }

    func getStoredCertificate(for hostname: String) -> StoredCertificate? {
        certificates.first { $0.hostname == hostname }
    }

    func storeCertificate(hostname: String, fingerprint: String, commonName: String) {
        guard !certificates.contains(where: { $0.hostname == hostname }) else { return }

        let certificate = StoredCertificate(
            hostname: hostname,
            fingerprint: fingerprint,
            commonName: commonName
        )
        certificates.append(certificate)
        saveCertificates()
    }

    func updateCertificate(hostname: String, fingerprint: String, commonName: String) {
        if let index = certificates.firstIndex(where: { $0.hostname == hostname }) {
            let existing = certificates[index]
            certificates[index] = StoredCertificate(
                id: existing.id,
                hostname: hostname,
                fingerprint: fingerprint,
                commonName: commonName,
                firstSeen: existing.firstSeen,
                lastSeen: Date()
            )
        } else {
            storeCertificate(hostname: hostname, fingerprint: fingerprint, commonName: commonName)
        }
        saveCertificates()
    }

    func updateLastSeen(for hostname: String) {
        if let index = certificates.firstIndex(where: { $0.hostname == hostname }) {
            var cert = certificates[index]
            cert.lastSeen = Date()
            certificates[index] = cert
            saveCertificates()
        }
    }

    func removeCertificate(for hostname: String) {
        certificates.removeAll { $0.hostname == hostname }
        saveCertificates()
    }

    private func saveCertificates() {
        if let data = try? JSONEncoder().encode(certificates) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadCertificates() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([StoredCertificate].self, from: data) else {
            return
        }
        certificates = decoded
    }

    // MARK: - Certificate Extraction Helpers

    static func extractCertificateInfo(from secTrust: SecTrust) -> (fingerprint: String, commonName: String)? {
        guard let chain = SecTrustCopyCertificateChain(secTrust) as? [SecCertificate],
              let leafCert = chain.first else {
            return nil
        }

        let certData = SecCertificateCopyData(leafCert) as Data
        let fingerprint = sha256Fingerprint(certData)
        let commonName = SecCertificateCopySubjectSummary(leafCert) as String? ?? "Unknown"

        return (fingerprint, commonName)
    }

    static func sha256Fingerprint(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined(separator: ":")
    }
}
