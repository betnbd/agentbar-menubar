import Foundation

public enum KeychainAccessGate {
    private static let flagKey = "debugDisableKeychainAccess"
    @TaskLocal private static var taskOverrideValue: Bool?
    private nonisolated(unsafe) static var overrideValue: Bool?

    public nonisolated(unsafe) static var isDisabled: Bool {
        get {
            if let taskOverrideValue { return taskOverrideValue }
            #if DEBUG
            if Self.forcesDisabledUnderTests {
                return true
            }
            #endif
            if let overrideValue { return overrideValue }
            return UserDefaults.standard.bool(forKey: Self.flagKey)
        }
        set {
            overrideValue = newValue
        }
    }

    #if DEBUG
    private nonisolated(unsafe) static var forcesDisabledUnderTests: Bool {
        self.isRunningUnderTests
            && ProcessInfo.processInfo.environment["AGENTBAR_ALLOW_TEST_KEYCHAIN_ACCESS"] != "1"
    }

    private nonisolated(unsafe) static var isRunningUnderTests: Bool {
        let processName = ProcessInfo.processInfo.processName
        return processName == "swiftpm-testing-helper"
            || processName.hasSuffix("PackageTests")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    #endif

    static func withTaskOverrideForTesting<T>(
        _ disabled: Bool?,
        operation: () throws -> T) rethrows -> T
    {
        try self.$taskOverrideValue.withValue(disabled) {
            try operation()
        }
    }

    static func withTaskOverrideForTesting<T>(
        _ disabled: Bool?,
        operation: () async throws -> T) async rethrows -> T
    {
        try await self.$taskOverrideValue.withValue(disabled) {
            try await operation()
        }
    }

    static var currentOverrideForTesting: Bool? {
        self.taskOverrideValue ?? self.overrideValue
    }

    #if DEBUG
    static func resetOverrideForTesting() {
        self.overrideValue = nil
    }
    #endif
}
