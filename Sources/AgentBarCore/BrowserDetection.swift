import Foundation

public struct BrowserDetection: Sendable {
    public static let defaultCacheTTL: TimeInterval = 0

    public init(
        homeDirectory: String = "",
        cacheTTL: TimeInterval = BrowserDetection.defaultCacheTTL,
        now: @escaping @Sendable () -> Date = Date.init,
        fileExists: @escaping @Sendable (String) -> Bool = { _ in false },
        directoryContents: @escaping @Sendable (String) -> [String]? = { _ in nil })
    {
        _ = homeDirectory
        _ = cacheTTL
        _ = now
        _ = fileExists
        _ = directoryContents
    }

    public func isAppInstalled(_ browser: Browser) -> Bool {
        _ = browser
        return false
    }

    public func isCookieSourceAvailable(_ browser: Browser) -> Bool {
        _ = browser
        return false
    }

    public func hasUsableProfileData(_ browser: Browser) -> Bool {
        _ = browser
        return false
    }

    public func clearCache() {}
}
