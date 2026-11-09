import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// App Group 共享存储（主 App 写入，Widget 读取）
public enum SharedStore {
    public static let appGroup = "group.cn.guizhou.weathergz"
    public static let fileName = "shared.json"

    private static var containerURL: URL? {
        #if canImport(Darwin)
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        #else
        return nil
        #endif
    }

    public static var fileURL: URL {
        if let c = containerURL { return c.appendingPathComponent(fileName) }
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    public static func save(_ snapshot: WeatherSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    public static func load() -> WeatherSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WeatherSnapshot.self, from: data)
    }

    /// 快照超过 20 分钟视为过期（刷新间隔 10 分钟）
    public static func isStale(_ s: WeatherSnapshot) -> Bool {
        Date().timeIntervalSince(s.fetchedAt) > 20 * 60
    }

    #if canImport(WidgetKit)
    public static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    #endif
}
