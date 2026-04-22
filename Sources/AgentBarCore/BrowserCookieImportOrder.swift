public struct Browser: Sendable, Hashable {
    public init() {}
}

public typealias BrowserCookieImportOrder = [Browser]

extension [Browser] {
    public func cookieImportCandidates(using detection: BrowserDetection) -> [Browser] {
        self.filter { detection.isCookieSourceAvailable($0) && BrowserCookieAccessGate.shouldAttempt($0) }
    }

    public func browsersWithProfileData(using detection: BrowserDetection) -> [Browser] {
        self.filter { detection.hasUsableProfileData($0) }
    }
}
