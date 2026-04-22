import Foundation

@MainActor
public struct OpenAIDashboardFetcher {
    public enum FetchError: LocalizedError {
        case loginRequired
        case noDashboardData(body: String)

        public var errorDescription: String? {
            switch self {
            case .loginRequired:
                "OpenAI web access requires login."
            case let .noDashboardData(body):
                "OpenAI dashboard data not found. Body sample: \(body.prefix(200))"
            }
        }
    }

    public init() {}

    public func loadLatestDashboard(
        accountEmail _: String?,
        logger _: ((String) -> Void)? = nil,
        debugDumpHTML _: Bool = false,
        timeout _: TimeInterval = 60) async throws -> OpenAIDashboardSnapshot
    {
        throw FetchError.noDashboardData(body: "OpenAI web dashboard fetch is not available in this Linux build.")
    }
}
