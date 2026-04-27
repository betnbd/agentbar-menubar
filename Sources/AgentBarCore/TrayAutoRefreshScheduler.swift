import Foundation

public struct TrayAutoRefreshScheduler: Sendable {
    public typealias RefreshAction = @Sendable () async -> Void
    public typealias SleepAction = @Sendable (TimeInterval) async throws -> Void

    private let interval: TimeInterval
    private let sleep: SleepAction
    private let refresh: RefreshAction

    public init(
        interval: TimeInterval,
        sleep: @escaping SleepAction = { interval in
            try await Task.sleep(for: .seconds(interval))
        },
        refresh: @escaping RefreshAction)
    {
        self.interval = interval
        self.sleep = sleep
        self.refresh = refresh
    }

    public func run() async {
        while !Task.isCancelled {
            do {
                try await self.sleep(self.interval)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await self.refresh()
        }
    }
}
