import XCTest
@testable import VoicePolishCore

/// 永远写失败的存储，用于验证 fail-closed（写不进就不删明文）。
private final class FailingStore: SecretStoring {
    func get(_ a: String) -> String? { nil }
    @discardableResult func set(_ a: String, _ v: String?) -> Bool { false }
}

final class SecretStoreRoutingTests: XCTestCase {

    private func tmpConfig(_ secrets: SecretStoring, seed: String? = nil) -> (VoicePolishConfig, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vpcfg-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let seed = seed {
            try? seed.write(to: dir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        }
        return (VoicePolishConfig(configDir: dir, secrets: secrets), dir)
    }

    private func configRaw(_ dir: URL) -> String {
        (try? String(contentsOf: dir.appendingPathComponent("config.json"), encoding: .utf8)) ?? ""
    }

    // MARK: - SecretStore

    func testInMemorySecretStoreRoundTrip() {
        let s = InMemorySecretStore()
        XCTAssertNil(s.get("k"))
        XCTAssertTrue(s.set("k", "v"))
        XCTAssertEqual(s.get("k"), "v")
        XCTAssertTrue(s.set("k", nil))   // nil = 删除
        XCTAssertNil(s.get("k"))
        XCTAssertTrue(s.set("k", ""))    // 空串 = 删除
        XCTAssertNil(s.get("k"))
    }

    // MARK: - saveSecret 路由

    func testSaveSecretWritesKeychainAndStripsPlaintext() throws {
        let secrets = InMemorySecretStore()
        let (cfg, dir) = tmpConfig(secrets, seed: #"{"ark_api_key":"sk-OLD","polish_provider":"omni"}"#)
        XCTAssertEqual(cfg.string(forKey: "ark_api_key"), "sk-OLD")   // 迁移前明文兜底
        XCTAssertTrue(cfg.saveSecret("sk-NEW", forKey: "ark_api_key"))
        XCTAssertEqual(secrets.get("ark_api_key"), "sk-NEW")
        let raw = configRaw(dir)
        XCTAssertFalse(raw.contains("sk-OLD"))
        XCTAssertFalse(raw.contains("sk-NEW"))   // 永不写进 config
        XCTAssertTrue(raw.contains("omni"))      // 非 secret 保留
    }

    func testSaveSecretEmptyDeletes() {
        let secrets = InMemorySecretStore(); _ = secrets.set("ark_api_key", "sk-1")
        let (cfg, _) = tmpConfig(secrets)
        XCTAssertTrue(cfg.saveSecret("", forKey: "ark_api_key"))   // 空 = 删除（删 key）
        XCTAssertNil(secrets.get("ark_api_key"))
    }

    func testSaveSecretFailureKeepsPlaintext() {
        let (cfg, dir) = tmpConfig(FailingStore(), seed: #"{"ark_api_key":"sk-OLD"}"#)
        XCTAssertFalse(cfg.saveSecret("sk-NEW", forKey: "ark_api_key"))  // 写失败
        XCTAssertTrue(configRaw(dir).contains("sk-OLD"))                  // 明文保留，不丢
    }

    func testNonSecretSaveValuesNeverWritesSecretToConfig() {
        let secrets = InMemorySecretStore()
        let (cfg, dir) = tmpConfig(secrets)
        cfg.save(values: ["ark_api_key": "sk-X", "polish_provider": "qwen"])
        XCTAssertEqual(secrets.get("ark_api_key"), "sk-X")   // secret 进 Keychain
        let raw = configRaw(dir)
        XCTAssertFalse(raw.contains("sk-X"))                 // 不进 config
        XCTAssertTrue(raw.contains("qwen"))
    }

    /// custom_api_key（自定义模型档）也走钥匙串路由：明文残留会被收敛，config 永不落明文。
    func testCustomAPIKeyRoutesToKeychain() throws {
        let secrets = InMemorySecretStore()
        let (cfg, dir) = tmpConfig(secrets, seed: #"{"custom_api_key":"sk-PLAIN","custom_polish_base_url":"https://api.deepseek.com"}"#)
        XCTAssertEqual(cfg.string(forKey: "custom_api_key"), "sk-PLAIN")   // 迁移前明文兜底
        cfg.reconcileSecrets()
        XCTAssertEqual(secrets.get("custom_api_key"), "sk-PLAIN")         // 收敛进钥匙串
        let raw = configRaw(dir)
        XCTAssertFalse(raw.contains("sk-PLAIN"))                           // 明文已删
        XCTAssertTrue(raw.contains("api.deepseek.com"))                    // 非 secret 保留
    }

    // MARK: - reconcileSecrets

    func testReconcileStripsPlaintextWhenKeychainEqualOrEmpty() throws {
        let secrets = InMemorySecretStore()
        let (cfg, dir) = tmpConfig(secrets, seed: #"{"ark_api_key":"sk-OLD","dashscope_api_key":"ds-1","polish_provider":"omni"}"#)
        cfg.reconcileSecrets()
        XCTAssertEqual(secrets.get("ark_api_key"), "sk-OLD")
        XCTAssertEqual(secrets.get("dashscope_api_key"), "ds-1")
        let raw = configRaw(dir)
        XCTAssertFalse(raw.contains("sk-OLD"))   // 确认相等可读后才删
        XCTAssertFalse(raw.contains("ds-1"))
        XCTAssertTrue(raw.contains("omni"))      // 非 secret 保留
    }

    func testReconcileKeepsPlaintextWhenKeychainWriteFails() {
        let (cfg, dir) = tmpConfig(FailingStore(), seed: #"{"ark_api_key":"sk-OLD"}"#)
        cfg.reconcileSecrets()
        XCTAssertTrue(configRaw(dir).contains("sk-OLD"))   // 没确认就绝不删
    }

    func testReconcileConflictKeychainWinsAndRemovesPlaintext() {
        // 模拟「saveSecret 删明文失败」残留：Keychain=NEW，config 明文=OLD
        let secrets = InMemorySecretStore(); _ = secrets.set("ark_api_key", "sk-NEW")
        let (cfg, dir) = tmpConfig(secrets, seed: #"{"ark_api_key":"sk-OLD"}"#)
        cfg.reconcileSecrets()
        XCTAssertEqual(secrets.get("ark_api_key"), "sk-NEW")          // 绝不被陈旧明文覆盖
        XCTAssertEqual(cfg.string(forKey: "ark_api_key"), "sk-NEW")   // string 以 Keychain 为准
        XCTAssertFalse(configRaw(dir).contains("sk-OLD"))             // 陈旧明文副本不再保留
    }

    #if os(macOS)
    func testConfigDirectoryAndFileUsePrivatePermissions() throws {
        let (cfg, dir) = tmpConfig(InMemorySecretStore())
        cfg.save(value: "omni", forKey: "polish_provider")

        let dirMode = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: dir.path)[.posixPermissions] as? NSNumber)
        let fileMode = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent("config.json").path)[.posixPermissions] as? NSNumber)
        XCTAssertEqual(dirMode.intValue & 0o777, 0o700)
        XCTAssertEqual(fileMode.intValue & 0o777, 0o600)
    }
    #endif
}
