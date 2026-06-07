import CCommonCrypto
import Foundation
import Security

enum SecurityError: Error, LocalizedError {
    case randomFailed
    case keyDerivationFailed

    var errorDescription: String? {
        switch self {
        case .randomFailed: "난수 생성에 실패했습니다."
        case .keyDerivationFailed: "비밀번호 해시에 실패했습니다."
        }
    }
}

private let recoveryAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
private let choseongKeys = ["r", "R", "s", "e", "E", "f", "a", "q", "Q", "t", "T", "d", "w", "W", "c", "z", "x", "v", "g"]
private let jungseongKeys = ["k", "o", "i", "O", "j", "p", "u", "P", "h", "hk", "ho", "hl", "y", "n", "nj", "np", "nl", "b", "m", "ml", "l"]
private let jongseongKeys = ["", "r", "R", "rt", "s", "sw", "sg", "e", "f", "fr", "fa", "fq", "ft", "fx", "fv", "fg", "a", "q", "qt", "t", "T", "d", "w", "c", "z", "x", "v", "g"]
private let jamoKeys: [Character: String] = [
    "ㄱ": "r", "ㄲ": "R", "ㄳ": "rt", "ㄴ": "s", "ㄵ": "sw", "ㄶ": "sg", "ㄷ": "e", "ㄸ": "E",
    "ㄹ": "f", "ㄺ": "fr", "ㄻ": "fa", "ㄼ": "fq", "ㄽ": "ft", "ㄾ": "fx", "ㄿ": "fv", "ㅀ": "fg",
    "ㅁ": "a", "ㅂ": "q", "ㅃ": "Q", "ㅄ": "qt", "ㅅ": "t", "ㅆ": "T", "ㅇ": "d", "ㅈ": "w",
    "ㅉ": "W", "ㅊ": "c", "ㅋ": "z", "ㅌ": "x", "ㅍ": "v", "ㅎ": "g", "ㅏ": "k", "ㅐ": "o",
    "ㅑ": "i", "ㅒ": "O", "ㅓ": "j", "ㅔ": "p", "ㅕ": "u", "ㅖ": "P", "ㅗ": "h", "ㅘ": "hk",
    "ㅙ": "ho", "ㅚ": "hl", "ㅛ": "y", "ㅜ": "n", "ㅝ": "nj", "ㅞ": "np", "ㅟ": "nl", "ㅠ": "b",
    "ㅡ": "m", "ㅢ": "ml", "ㅣ": "l"
]

func randomBytes(count: Int) throws -> Data {
    var data = Data(count: count)
    let status = data.withUnsafeMutableBytes { buffer in
        SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
    }
    guard status == errSecSuccess else { throw SecurityError.randomFailed }
    return data
}

func urlSafeBase64(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
}

func dataFromURLSafeBase64(_ value: String) -> Data {
    var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while base64.count % 4 != 0 {
        base64.append("=")
    }
    return Data(base64Encoded: base64) ?? Data()
}

func generateSalt() throws -> String {
    try urlSafeBase64(randomBytes(count: 24))
}

func normalizeRecoveryKey(_ value: String) -> String {
    value.uppercased().filter { $0.isLetter || $0.isNumber }
}

func normalizeKeyboardSecret(_ value: String) -> String {
    var normalized = ""
    for scalar in value.unicodeScalars {
        let code = scalar.value
        if code >= 0xAC00 && code <= 0xD7A3 {
            let offset = Int(code - 0xAC00)
            normalized += choseongKeys[offset / 588]
            normalized += jungseongKeys[(offset % 588) / 28]
            normalized += jongseongKeys[offset % 28]
            continue
        }
        let character = Character(scalar)
        normalized += jamoKeys[character] ?? String(character)
    }
    return normalized
}

func hashSecret(_ secret: String, salt: String, iterations: Int = pbkdf2Iterations) throws -> String {
    let saltData = dataFromURLSafeBase64(salt)
    let passwordData = Data(secret.utf8)
    var derived = Data(count: 32)
    let derivedCount = derived.count
    let status = derived.withUnsafeMutableBytes { derivedBuffer in
        saltData.withUnsafeBytes { saltBuffer in
            passwordData.withUnsafeBytes { passwordBuffer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBuffer.bindMemory(to: Int8.self).baseAddress,
                    passwordData.count,
                    saltBuffer.bindMemory(to: UInt8.self).baseAddress,
                    saltData.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    derivedBuffer.bindMemory(to: UInt8.self).baseAddress,
                    derivedCount
                )
            }
        }
    }
    guard status == kCCSuccess else { throw SecurityError.keyDerivationFailed }
    return urlSafeBase64(derived)
}

func verifySecret(_ secret: String, salt: String, expectedHash: String, iterations: Int) -> Bool {
    guard let actual = try? hashSecret(secret, salt: salt, iterations: iterations) else {
        return false
    }
    return constantTimeEquals(actual, expectedHash)
}

func constantTimeEquals(_ left: String, _ right: String) -> Bool {
    let leftData = Data(left.utf8)
    let rightData = Data(right.utf8)
    let maxCount = max(leftData.count, rightData.count)
    var difference = leftData.count ^ rightData.count
    for index in 0..<maxCount {
        let leftByte = index < leftData.count ? leftData[index] : 0
        let rightByte = index < rightData.count ? rightData[index] : 0
        difference |= Int(leftByte ^ rightByte)
    }
    return difference == 0
}

func generateRecoveryKey() throws -> String {
    var groups: [String] = []
    for _ in 0..<5 {
        var group = ""
        for _ in 0..<4 {
            let byte = try randomBytes(count: 1)[0]
            group.append(recoveryAlphabet[Int(byte) % recoveryAlphabet.count])
        }
        groups.append(group)
    }
    return groups.joined(separator: "-")
}
