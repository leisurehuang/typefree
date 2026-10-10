// CryptoKit Ed25519 签名（被 make_appcast.sh 调用）：
// 签名输出与 Sparkle 的 edSignature 逐字节一致（两者均为 RFC 8032 对文件整字节的确定性签名，
// 客户端 SUSignatureVerifier 用裸 ed25519_verify 校验）。私钥格式：64B（seed||pub）base64；
// 官方 sign_update 吃 32B seed = 本格式 base64 的前 44 个字符。读 DMG_PATH / SPARKLE_PRIVATE_KEY。
import Foundation
import CryptoKit

guard let privB64 = ProcessInfo.processInfo.environment["SPARKLE_PRIVATE_KEY"],
      let privData = Data(base64Encoded: privB64), privData.count == 64,
      let dmgPath = ProcessInfo.processInfo.environment["DMG_PATH"] else {
    FileHandle.standardError.write("私钥格式错误（需 64B seed||pub 的 base64）\n".data(using: .utf8)!)
    exit(1)
}
let seed = privData.prefix(32)
let pub = privData.suffix(32)
guard let priv = try? Curve25519.Signing.PrivateKey(rawRepresentation: seed) else {
    FileHandle.standardError.write("无法从 seed 重建私钥\n".data(using: .utf8)!)
    exit(1)
}
// 双保险：重建出的公钥必须与私钥后 32 字节一致（防私钥格式错位）
guard priv.publicKey.rawRepresentation == pub else {
    FileHandle.standardError.write("私钥 seed 与公钥段不匹配\n".data(using: .utf8)!)
    exit(1)
}

guard let dmgData = try? Data(contentsOf: URL(fileURLWithPath: dmgPath)) else {
    FileHandle.standardError.write("读不到 DMG: \(dmgPath)\n".data(using: .utf8)!)
    exit(1)
}
guard let sig = try? priv.signature(for: dmgData) else {
    FileHandle.standardError.write("签名失败\n".data(using: .utf8)!)
    exit(1)
}
print(sig.base64EncodedString())
