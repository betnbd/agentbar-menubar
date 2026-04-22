import Foundation

public protocol NotificationPosting: Sendable {
    func requestAuthorizationIfNeeded() async -> Bool
    func post(idPrefix: String, title: String, body: String, badge: NSNumber?) async
}

public protocol LaunchAtLoginControlling: Sendable {
    func setEnabled(_ enabled: Bool)
    func isEnabled() -> Bool
}

public protocol ExternalURLOpening: Sendable {
    func open(_ url: URL)
}

public struct PlatformServices: Sendable {
    public let notifications: any NotificationPosting
    public let launchAtLoginController: any LaunchAtLoginControlling
    public let externalURLHandler: any ExternalURLOpening

    public init(
        notifications: any NotificationPosting,
        launchAtLoginController: any LaunchAtLoginControlling,
        externalURLHandler: any ExternalURLOpening)
    {
        self.notifications = notifications
        self.launchAtLoginController = launchAtLoginController
        self.externalURLHandler = externalURLHandler
    }

    public static let noOp = PlatformServices(
        notifications: NoOpNotificationPoster(),
        launchAtLoginController: NoOpLaunchAtLoginController(),
        externalURLHandler: NoOpExternalURLHandler())
}

public struct NoOpNotificationPoster: NotificationPosting {
    public init() {}

    public func requestAuthorizationIfNeeded() async -> Bool {
        false
    }

    public func post(idPrefix _: String, title _: String, body _: String, badge _: NSNumber?) async {}
}

public struct NoOpLaunchAtLoginController: LaunchAtLoginControlling {
    public init() {}

    public func setEnabled(_: Bool) {}

    public func isEnabled() -> Bool {
        false
    }
}

public struct NoOpExternalURLHandler: ExternalURLOpening {
    public init() {}

    public func open(_: URL) {}
}
