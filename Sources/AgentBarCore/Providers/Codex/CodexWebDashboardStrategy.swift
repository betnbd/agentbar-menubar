public struct CodexWebDashboardStrategy: ProviderFetchStrategy {
    public let id: String = "codex.web.dashboard"
    public let kind: ProviderFetchKind = .webDashboard

    public init() {}

    public func isAvailable(_: ProviderFetchContext) async -> Bool {
        false
    }

    public func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
        throw ProviderFetchError.noAvailableStrategy(.codex)
    }

    public func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}
