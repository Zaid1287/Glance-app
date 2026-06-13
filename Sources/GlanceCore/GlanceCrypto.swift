import Foundation
import CryptoKit

/// The pairing secret and the encrypted wire codec.
///
/// Task metadata must never leave the Mac in the clear (N3). Every wire frame is
/// sealed with ChaChaPoly (AEAD) under a 256-bit key shared only between the Mac
/// and its paired peer. Because only key-holders can produce a frame that opens,
/// this gives peer **authentication** for free: anything that fails to decrypt —
/// a stranger on the LAN, a port scanner, a corrupted packet — is dropped.
public enum GlanceCrypto {
    public enum CryptoError: Error { case badKeyFile }

    public static func defaultKeyURL() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".glance/key")
    }

    /// Load the pairing key, creating a fresh one (0600) if none exists. In
    /// production the key arrives via QR + key exchange; persisting it to a
    /// user-only file is the local stand-in.
    public static func loadOrCreateKey(at url: URL) throws -> SymmetricKey {
        if let key = try? loadKey(at: url) { return key }
        let key = SymmetricKey(size: .bits256)
        let raw = key.withUnsafeBytes { Data($0) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (raw.base64EncodedString() + "\n").data(using: .utf8)!
            .write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return key
    }

    public static func loadKey(at url: URL) throws -> SymmetricKey {
        guard let data = FileManager.default.contents(atPath: url.path),
              let text = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              let raw = Data(base64Encoded: text), raw.count == 32
        else { throw CryptoError.badKeyFile }
        return SymmetricKey(data: raw)
    }

    /// Short non-secret fingerprint so a user can confirm two devices share the
    /// same key without revealing it.
    public static func fingerprint(_ key: SymmetricKey) -> String {
        let digest = SHA256.hash(data: key.withUnsafeBytes { Data($0) })
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }
}

/// AEAD-encrypted, newline-framed wire codec. Frames are base64 so the ciphertext
/// can never collide with the `\n` delimiter. `open` returns nil on any failure
/// (oversized, non-base64, wrong key, tampered) — callers simply ignore it.
public struct SecureCodec {
    public enum Failure: Error { case oversized, malformed }

    private let key: SymmetricKey
    public let maxFrameBytes: Int

    public init(key: SymmetricKey, maxFrameBytes: Int = 256 * 1024) {
        self.key = key
        self.maxFrameBytes = maxFrameBytes
    }

    /// Seal an envelope into one base64 line (with trailing newline).
    public func seal(_ envelope: TaskEnvelope, nonce: ChaChaPoly.Nonce = ChaChaPoly.Nonce()) -> Data {
        let plaintext = WireCodec.encode(envelope)
        guard let box = try? ChaChaPoly.seal(plaintext, using: key, nonce: nonce) else { return Data() }
        var line = box.combined.base64EncodedData()
        line.append(0x0A)
        return line
    }

    /// Open one frame (without the trailing newline). Nil on any failure.
    public func open(_ frame: Data) -> TaskEnvelope? {
        guard frame.count <= maxFrameBytes,
              let text = String(data: frame, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              let combined = Data(base64Encoded: text),
              let box = try? ChaChaPoly.SealedBox(combined: combined),
              let plaintext = try? ChaChaPoly.open(box, using: key)
        else { return nil }
        return WireCodec.decode(plaintext)
    }
}
