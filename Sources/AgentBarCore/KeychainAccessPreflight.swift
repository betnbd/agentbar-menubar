import Foundation

public struct KeychainPromptContext: Sendable {
    public enum Kind: Sendable {
        case claudeOAuth
        case codexCookie
        case claudeCookie
        case opencodeCookie
        case zaiToken
        case syntheticToken
        case copilotToken
        case kimiToken
        case kimiK2Token
        case minimaxCookie
        case minimaxToken
        case ampCookie
    }

    public let kind: Kind
    public let service: String
    public let account: String?

    public init(kind: Kind, service: String, account: String?) {
        self.kind = kind
        self.service = service
        self.account = account
    }
}

public enum KeychainPromptHandler {
    final class HandlerStore: @unchecked Sendable {
        let handler: (KeychainPromptContext) -> Void

        init(handler: @escaping (KeychainPromptContext) -> Void) {
            self.handler = handler
        }
    }

    @TaskLocal private static var taskHandlerStore: HandlerStore?
    public nonisolated(unsafe) static var handler: ((KeychainPromptContext) -> Void)?

    public static func notify(_ context: KeychainPromptContext) {
        if let taskHandlerStore {
            taskHandlerStore.handler(context)
            return
        }
        self.handler?(context)
    }

    #if DEBUG
    static func withHandlerForTesting<T>(
        _ handler: ((KeychainPromptContext) -> Void)?,
        operation: () throws -> T) rethrows -> T
    {
        try self.$taskHandlerStore.withValue(handler.map(HandlerStore.init(handler:))) {
            try operation()
        }
    }

    static func withHandlerForTesting<T>(
        _ handler: ((KeychainPromptContext) -> Void)?,
        operation: () async throws -> T) async rethrows -> T
    {
        try await self.$taskHandlerStore.withValue(handler.map(HandlerStore.init(handler:))) {
            try await operation()
        }
    }
    #endif
}

public enum KeychainAccessPreflight {
    public enum Outcome: Sendable {
        case allowed
        case interactionRequired
        case notFound
        case failure(Int)
    }

    #if DEBUG
    final class CheckGenericPasswordOverrideStore: @unchecked Sendable {
        let check: (String, String?) -> Outcome

        init(check: @escaping (String, String?) -> Outcome) {
            self.check = check
        }
    }

    @TaskLocal private static var taskCheckGenericPasswordOverrideStore: CheckGenericPasswordOverrideStore?
    private nonisolated(unsafe) static var checkGenericPasswordOverride: ((String, String?) -> Outcome)?

    static func setCheckGenericPasswordOverrideForTesting(_ override: ((String, String?) -> Outcome)?) {
        self.checkGenericPasswordOverride = override
    }

    static func withCheckGenericPasswordOverrideForTesting<T>(
        _ override: ((String, String?) -> Outcome)?,
        operation: () throws -> T) rethrows -> T
    {
        try self.$taskCheckGenericPasswordOverrideStore.withValue(
            override.map(CheckGenericPasswordOverrideStore.init(check:)))
        {
            try operation()
        }
    }

    static func withCheckGenericPasswordOverrideForTesting<T>(
        _ override: ((String, String?) -> Outcome)?,
        operation: () async throws -> T) async rethrows -> T
    {
        try await self.$taskCheckGenericPasswordOverrideStore.withValue(
            override.map(CheckGenericPasswordOverrideStore.init(check:)))
        {
            try await operation()
        }
    }
    #endif

    public static func checkGenericPassword(service: String, account: String?) -> Outcome {
        #if DEBUG
        if let override = self.taskCheckGenericPasswordOverrideStore {
            return override.check(service, account)
        }
        if let override = self.checkGenericPasswordOverride {
            return override(service, account)
        }
        #endif
        _ = service
        _ = account
        return .notFound
    }
}
