import Foundation

extension TokenAccountSupportCatalog {
    static let supportByProvider: [UsageProvider: TokenAccountSupport] = [
        .claude: TokenAccountSupport(
            title: "Session tokens",
            subtitle: "Store Claude sessionKey cookies or OAuth access tokens.",
            placeholder: "Paste sessionKey or OAuth token…",
            injection: .cookieHeader,
            requiresManualCookieSource: true,
            cookieName: "sessionKey"),
        .zai: TokenAccountSupport(
            title: "API tokens",
            subtitle: "Stored in the AgentBar config file.",
            placeholder: "Paste token…",
            injection: .environment(key: ZaiSettingsReader.apiTokenKey),
            requiresManualCookieSource: false,
            cookieName: nil),
        .opencode: TokenAccountSupport(
            title: "Session tokens",
            subtitle: "Store multiple OpenCode Cookie headers.",
            placeholder: "Cookie: …",
            injection: .cookieHeader,
            requiresManualCookieSource: true,
            cookieName: nil),
        .opencodego: TokenAccountSupport(
            title: "Session tokens",
            subtitle: "Store multiple OpenCode Go Cookie headers.",
            placeholder: "Cookie: …",
            injection: .cookieHeader,
            requiresManualCookieSource: true,
            cookieName: nil),
        .minimax: TokenAccountSupport(
            title: "Session tokens",
            subtitle: "Store multiple MiniMax Cookie headers.",
            placeholder: "Cookie: …",
            injection: .cookieHeader,
            requiresManualCookieSource: true,
            cookieName: nil),
        .ollama: TokenAccountSupport(
            title: "Session tokens",
            subtitle: "Store multiple Ollama Cookie headers.",
            placeholder: "Cookie: …",
            injection: .cookieHeader,
            requiresManualCookieSource: true,
            cookieName: nil),
    ]
}
