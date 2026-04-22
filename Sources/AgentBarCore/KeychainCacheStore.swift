import Foundation

public enum KeychainCacheStore {
    public struct Key: Hashable, Sendable {
        public let category: String
        public let identifier: String

        public init(category: String, identifier: String) {
            self.category = category
            self.identifier = identifier
        }

        var account: String {
            "\(self.category).\(self.identifier)"
        }
    }

    public enum LoadResult<Entry> {
        case found(Entry)
        case missing
        case invalid
    }

    private static let log = AgentBarLog.logger(LogCategories.keychainCache)
    private static let cacheService = AppIdentity.keychainCacheService
    private nonisolated(unsafe) static var globalServiceOverride: String?
    @TaskLocal private static var serviceOverride: String?
    private static let testStoreLock = NSLock()

    private struct TestStoreKey: Hashable {
        let service: String
        let account: String
    }

    private nonisolated(unsafe) static var testStore: [TestStoreKey: Data]?
    private nonisolated(unsafe) static var testStoreRefCount = 0

    public static func load<Entry: Codable>(
        key: Key,
        as type: Entry.Type = Entry.self) -> LoadResult<Entry>
    {
        if let testResult = self.loadFromTestStore(key: key, as: type) {
            return testResult
        }

        let url = self.url(for: key)
        guard let data = try? Data(contentsOf: url) else { return .missing }

        let decoder = Self.makeDecoder()
        guard let decoded = try? decoder.decode(Entry.self, from: data) else {
            self.log.error("Failed to decode cache entry (\(key.account))")
            return .invalid
        }
        return .found(decoded)
    }

    public static func store(key: Key, entry: some Codable) {
        if self.storeInTestStore(key: key, entry: entry) {
            return
        }

        let encoder = Self.makeEncoder()
        guard let data = try? encoder.encode(entry) else {
            self.log.error("Failed to encode cache entry (\(key.account))")
            return
        }

        let url = self.url(for: key)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            self.log.error("Failed to write cache entry (\(key.account)): \(error.localizedDescription)")
        }
    }

    public static func clear(key: Key) {
        if self.clearTestStore(key: key) {
            return
        }

        let url = self.url(for: key)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func setServiceOverrideForTesting(_ service: String?) {
        self.globalServiceOverride = service
    }

    public static func withServiceOverrideForTesting<T>(
        _ service: String?,
        operation: () throws -> T) rethrows -> T
    {
        try self.$serviceOverride.withValue(service) {
            try operation()
        }
    }

    public static func withServiceOverrideForTesting<T>(
        _ service: String?,
        operation: () async throws -> T) async rethrows -> T
    {
        try await self.$serviceOverride.withValue(service) {
            try await operation()
        }
    }

    public static func withCurrentServiceOverrideForTesting<T>(
        operation: () async throws -> T) async rethrows -> T
    {
        let service = self.serviceOverride
        return try await self.$serviceOverride.withValue(service) {
            try await operation()
        }
    }

    public static var currentServiceOverrideForTesting: String? {
        self.serviceOverride
    }

    static func setTestStoreForTesting(_ enabled: Bool) {
        self.testStoreLock.lock()
        defer { self.testStoreLock.unlock() }
        if enabled {
            self.testStoreRefCount += 1
            if self.testStoreRefCount == 1 {
                self.testStore = [:]
            }
        } else {
            self.testStoreRefCount = max(0, self.testStoreRefCount - 1)
            if self.testStoreRefCount == 0 {
                self.testStore = nil
            }
        }
    }

    private static var serviceName: String {
        serviceOverride ?? self.globalServiceOverride ?? self.cacheService
    }

    private static func cacheDirectory() -> URL {
        AppGroupSupport.localFallbackDirectory()
            .appendingPathComponent("cache", isDirectory: true)
            .appendingPathComponent(self.sanitized(self.serviceName), isDirectory: true)
    }

    private static func url(for key: Key) -> URL {
        self.cacheDirectory()
            .appendingPathComponent(self.sanitized(key.category), isDirectory: true)
            .appendingPathComponent("\(self.sanitized(key.identifier)).json", isDirectory: false)
    }

    private static func sanitized(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return raw.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func loadFromTestStore<Entry: Codable>(
        key: Key,
        as type: Entry.Type) -> LoadResult<Entry>?
    {
        self.testStoreLock.lock()
        defer { self.testStoreLock.unlock() }
        guard let store = self.testStore else { return nil }
        let testKey = TestStoreKey(service: self.serviceName, account: key.account)
        guard let data = store[testKey] else { return .missing }
        let decoder = Self.makeDecoder()
        guard let decoded = try? decoder.decode(Entry.self, from: data) else {
            return .invalid
        }
        return .found(decoded)
    }

    private static func storeInTestStore(key: Key, entry: some Codable) -> Bool {
        self.testStoreLock.lock()
        defer { self.testStoreLock.unlock() }
        guard var store = self.testStore else { return false }
        let encoder = Self.makeEncoder()
        guard let data = try? encoder.encode(entry) else { return true }
        let testKey = TestStoreKey(service: self.serviceName, account: key.account)
        store[testKey] = data
        self.testStore = store
        return true
    }

    private static func clearTestStore(key: Key) -> Bool {
        self.testStoreLock.lock()
        defer { self.testStoreLock.unlock() }
        guard var store = self.testStore else { return false }
        let testKey = TestStoreKey(service: self.serviceName, account: key.account)
        store.removeValue(forKey: testKey)
        self.testStore = store
        return true
    }
}

extension KeychainCacheStore.Key {
    public static func cookie(provider: UsageProvider, scopeIdentifier: String? = nil) -> Self {
        let identifier: String = if let scopeIdentifier, !scopeIdentifier.isEmpty {
            "\(provider.rawValue).\(scopeIdentifier)"
        } else {
            provider.rawValue
        }
        return Self(category: "cookie", identifier: identifier)
    }

    public static func oauth(provider: UsageProvider) -> Self {
        Self(category: "oauth", identifier: provider.rawValue)
    }
}
