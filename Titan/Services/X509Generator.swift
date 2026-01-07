//
//  X509Generator.swift
//  Titan
//
//  Self-signed X.509 certificate generation using Security framework
//

import Foundation
import Security

enum X509GeneratorError: LocalizedError {
    case keyGenerationFailed(OSStatus)
    case publicKeyExtractionFailed
    case signingFailed
    case invalidKeyData

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let status):
            return "Key generation failed with status: \(status)"
        case .publicKeyExtractionFailed:
            return "Failed to extract public key data"
        case .signingFailed:
            return "Failed to sign certificate"
        case .invalidKeyData:
            return "Invalid key data format"
        }
    }
}

struct X509Generator {

    /// Generates a self-signed X.509 certificate with EC P-256 key
    /// - Parameters:
    ///   - commonName: The CN field for the certificate (typically the user's friendly name)
    ///   - validityDays: Number of days the certificate is valid (default 365)
    /// - Returns: Tuple of (DER-encoded certificate data, private key)
    static func generateSelfSignedCertificate(
        commonName: String,
        validityDays: Int = 365
    ) throws -> (certificateData: Data, privateKey: SecKey) {
        // Generate EC P-256 key pair
        let privateKey = try generateECKeyPair()

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw X509GeneratorError.publicKeyExtractionFailed
        }

        // Build the TBS (to-be-signed) certificate
        let tbsCertificate = try buildTBSCertificate(
            commonName: commonName,
            publicKey: publicKey,
            validityDays: validityDays
        )

        // Sign the TBS certificate
        let signature = try signData(tbsCertificate, with: privateKey)

        // Build the complete certificate
        let certificate = buildCertificate(
            tbsCertificate: tbsCertificate,
            signature: signature
        )

        return (certificate, privateKey)
    }

    // MARK: - Key Generation

    private static func generateECKeyPair() throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrIsPermanent as String: false
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw X509GeneratorError.keyGenerationFailed(-1)
        }

        return privateKey
    }

    // MARK: - Certificate Building

    private static func buildTBSCertificate(
        commonName: String,
        publicKey: SecKey,
        validityDays: Int
    ) throws -> Data {
        var tbs = Data()

        // Version: [0] EXPLICIT INTEGER { 2 } (v3)
        tbs.append(contentsOf: DER.contextTag(0, explicit: true, contents: DER.integer(2)))

        // Serial Number: Random positive integer
        let serialNumber = generateSerialNumber()
        tbs.append(contentsOf: DER.integer(serialNumber))

        // Signature Algorithm: ecdsa-with-SHA256 (1.2.840.10045.4.3.2)
        tbs.append(contentsOf: DER.sequence([
            DER.oid([1, 2, 840, 10045, 4, 3, 2])
        ]))

        // Issuer: CN=commonName
        let issuer = DER.rdnSequence(commonName: commonName)
        tbs.append(contentsOf: issuer)

        // Validity
        let now = Date()
        let expiry = Calendar.current.date(byAdding: .day, value: validityDays, to: now)!
        tbs.append(contentsOf: DER.sequence([
            DER.utcTime(now),
            DER.utcTime(expiry)
        ]))

        // Subject: Same as issuer (self-signed)
        tbs.append(contentsOf: issuer)

        // Subject Public Key Info
        let publicKeyInfo = try buildSubjectPublicKeyInfo(publicKey: publicKey)
        tbs.append(contentsOf: publicKeyInfo)

        return DER.sequence(tbs)
    }

    private static func buildSubjectPublicKeyInfo(publicKey: SecKey) throws -> Data {
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            throw X509GeneratorError.publicKeyExtractionFailed
        }

        // Algorithm: id-ecPublicKey (1.2.840.10045.2.1) with prime256v1 (1.2.840.10045.3.1.7)
        let algorithm = DER.sequence([
            DER.oid([1, 2, 840, 10045, 2, 1]),  // id-ecPublicKey
            DER.oid([1, 2, 840, 10045, 3, 1, 7]) // prime256v1 (P-256)
        ])

        // Public key is already in uncompressed point format (0x04 || x || y)
        let publicKeyBitString = DER.bitString(publicKeyData)

        return DER.sequence([algorithm, publicKeyBitString])
    }

    private static func buildCertificate(tbsCertificate: Data, signature: Data) -> Data {
        // Signature Algorithm: ecdsa-with-SHA256
        let signatureAlgorithm = DER.sequence([
            DER.oid([1, 2, 840, 10045, 4, 3, 2])
        ])

        // Signature Value (BIT STRING)
        let signatureValue = DER.bitString(signature)

        return DER.sequence([tbsCertificate, signatureAlgorithm, signatureValue])
    }

    // MARK: - Signing

    private static func signData(_ data: Data, with privateKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) as Data? else {
            throw X509GeneratorError.signingFailed
        }

        return signature
    }

    // MARK: - Helpers

    private static func generateSerialNumber() -> [UInt8] {
        // Generate a 16-byte random serial number
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        // Ensure it's positive by clearing the high bit
        bytes[0] &= 0x7F
        // Ensure it's non-zero
        if bytes.allSatisfy({ $0 == 0 }) {
            bytes[15] = 1
        }
        return bytes
    }
}

// MARK: - DER Encoding

private enum DER {
    // ASN.1 tag constants
    static let tagInteger: UInt8 = 0x02
    static let tagBitString: UInt8 = 0x03
    static let tagOctetString: UInt8 = 0x04
    static let tagNull: UInt8 = 0x05
    static let tagOID: UInt8 = 0x06
    static let tagUTF8String: UInt8 = 0x0C
    static let tagSequence: UInt8 = 0x30
    static let tagSet: UInt8 = 0x31
    static let tagUTCTime: UInt8 = 0x17
    static let tagGeneralizedTime: UInt8 = 0x18

    static func sequence(_ contents: Data) -> Data {
        return encode(tag: tagSequence, contents: contents)
    }

    static func sequence(_ elements: [Data]) -> Data {
        let contents = elements.reduce(Data()) { $0 + $1 }
        return encode(tag: tagSequence, contents: contents)
    }

    static func set(_ elements: [Data]) -> Data {
        let contents = elements.reduce(Data()) { $0 + $1 }
        return encode(tag: tagSet, contents: contents)
    }

    static func integer(_ value: Int) -> Data {
        var bytes = [UInt8]()
        var v = value

        if v == 0 {
            bytes = [0]
        } else {
            while v > 0 {
                bytes.insert(UInt8(v & 0xFF), at: 0)
                v >>= 8
            }
            // Add leading zero if high bit is set (to keep it positive)
            if bytes[0] & 0x80 != 0 {
                bytes.insert(0, at: 0)
            }
        }

        return encode(tag: tagInteger, contents: Data(bytes))
    }

    static func integer(_ bytes: [UInt8]) -> Data {
        var adjusted = bytes
        // Remove leading zeros but keep at least one byte
        while adjusted.count > 1 && adjusted[0] == 0 && adjusted[1] & 0x80 == 0 {
            adjusted.removeFirst()
        }
        // Add leading zero if high bit is set
        if adjusted[0] & 0x80 != 0 {
            adjusted.insert(0, at: 0)
        }
        return encode(tag: tagInteger, contents: Data(adjusted))
    }

    static func bitString(_ data: Data) -> Data {
        // Prepend unused bits count (0)
        var contents = Data([0x00])
        contents.append(data)
        return encode(tag: tagBitString, contents: contents)
    }

    static func octetString(_ data: Data) -> Data {
        return encode(tag: tagOctetString, contents: data)
    }

    static func utf8String(_ string: String) -> Data {
        return encode(tag: tagUTF8String, contents: Data(string.utf8))
    }

    static func oid(_ components: [Int]) -> Data {
        guard components.count >= 2 else { return Data() }

        var bytes = [UInt8]()

        // First two components are encoded as: first * 40 + second
        bytes.append(UInt8(components[0] * 40 + components[1]))

        // Remaining components use base-128 encoding
        for i in 2..<components.count {
            var value = components[i]
            var encoded = [UInt8]()

            encoded.append(UInt8(value & 0x7F))
            value >>= 7

            while value > 0 {
                encoded.insert(UInt8((value & 0x7F) | 0x80), at: 0)
                value >>= 7
            }

            bytes.append(contentsOf: encoded)
        }

        return encode(tag: tagOID, contents: Data(bytes))
    }

    static func utcTime(_ date: Date) -> Data {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let string = formatter.string(from: date)
        return encode(tag: tagUTCTime, contents: Data(string.utf8))
    }

    static func contextTag(_ tag: Int, explicit: Bool, contents: Data) -> Data {
        let tagByte: UInt8
        if explicit {
            tagByte = UInt8(0xA0 | (tag & 0x1F))
        } else {
            tagByte = UInt8(0x80 | (tag & 0x1F))
        }
        return encode(tag: tagByte, contents: contents)
    }

    static func rdnSequence(commonName: String) -> Data {
        // RDNSequence is a SEQUENCE of RelativeDistinguishedName (SET)
        // Each RDN contains AttributeTypeAndValue (SEQUENCE of OID and value)

        // OID for commonName: 2.5.4.3
        let cnOID = oid([2, 5, 4, 3])
        let cnValue = utf8String(commonName)
        let cnATV = sequence([cnOID, cnValue])
        let cnRDN = set([cnATV])

        return sequence([cnRDN])
    }

    private static func encode(tag: UInt8, contents: Data) -> Data {
        var result = Data([tag])
        result.append(contentsOf: encodeLength(contents.count))
        result.append(contents)
        return result
    }

    private static func encodeLength(_ length: Int) -> [UInt8] {
        if length < 128 {
            return [UInt8(length)]
        } else if length < 256 {
            return [0x81, UInt8(length)]
        } else if length < 65536 {
            return [0x82, UInt8(length >> 8), UInt8(length & 0xFF)]
        } else {
            // For larger lengths (unlikely for certificates)
            return [0x83, UInt8(length >> 16), UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF)]
        }
    }
}
