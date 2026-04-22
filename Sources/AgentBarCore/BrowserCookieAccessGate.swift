import Foundation

public enum BrowserCookieAccessGate {
    public static func shouldAttempt(_ browser: Browser, now: Date = Date()) -> Bool {
        _ = browser
        _ = now
        return true
    }

    public static func recordIfNeeded(_ error: Error, now: Date = Date()) {
        _ = error
        _ = now
    }

    public static func recordDenied(for browser: Browser, now: Date = Date()) {
        _ = browser
        _ = now
    }

    public static func resetForTesting() {}
}

#if os(macOS)
import SweetCookieKit

extension BrowserCookieClient {
    public func codexBarRecords(
        matching query: BrowserCookieQuery,
        in browser: Browser,
        logger: ((String) -> Void)? = nil) throws -> [BrowserCookieStoreRecords]
    {
        try self.records(matching: query, in: browser, logger: logger)
    }
}
#endif
