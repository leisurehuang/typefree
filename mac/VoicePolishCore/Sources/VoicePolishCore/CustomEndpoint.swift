import Foundation

/// 自定义端点 Base URL 规整 + 拼 path（润色 chat/completions、识别 audio/transcriptions 共用）。
/// 规则（与 OpenAI 生态习惯一致）：去首尾空白与尾斜杠；只认 http/https（防手滑填出奇怪 scheme）；
/// 已带完整 path 则原样使用；无法构成合法地址返回 nil（视为未配置）。
enum CustomEndpoint {
    static func normalizedBase(_ base: String?) -> String? {
        guard var trimmed = base?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        while trimmed.hasSuffix("/") { trimmed = String(trimmed.dropLast()) }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return trimmed
    }

    /// base + path；base 已以 path 结尾则原样用（用户粘了完整 endpoint 也不重复拼）。
    static func url(from base: String?, path: String) -> URL? {
        guard var trimmed = normalizedBase(base) else { return nil }
        if trimmed.hasSuffix(path) { return URL(string: trimmed) }
        trimmed += path
        return URL(string: trimmed)
    }
}
