import Foundation
import Combine

/// 主 App 数据仓库：官方接口拉取 + App Group 共享 + 10 分钟自动刷新
@MainActor
final class WeatherStore: ObservableObject {
    static let shared = WeatherStore()
    static let buildTag = "v2.4-gz"
    static let refreshInterval: TimeInterval = 10 * 60

    @Published var snapshot: WeatherSnapshot?
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var city: City {
        didSet {
            if let data = try? JSONEncoder().encode(city) {
                UserDefaults.standard.set(data, forKey: "city")
            }
            Task { await refresh() }
        }
    }

    private let client = WeatherClient()
    private var autoTask: Task<Void, Never>?

    private init() {
        snapshot = SharedStore.load()
        if let data = UserDefaults.standard.data(forKey: "city"),
           let c = try? JSONDecoder().decode(City.self, from: data) {
            city = c
        } else {
            city = CityData.defaultCity
        }
    }

    // MARK: 刷新

    func refresh() async {
        isLoading = true
        lastError = nil
        let c = city
        // 乡镇级 ID（10 位）官方实况/逐天不支持，回退到所属区县（前 9 位）
        let apiID = c.id.count > 9 ? String(c.id.prefix(9)) : c.id
        do {
            async let cur = try? client.fetchCurrent(cityID: apiID)
            async let di = try? client.fetchDailyAndAlerts(cityID: apiID)
            async let mf = try? client.fetchMinute(lat: c.lat, lon: c.lon)

            let current = try? await cur
            let (days, alerts) = (try? await di) ?? ([], [])
            let minute = (try? await mf) ?? MinuteForecast()

            guard current != nil || !days.isEmpty || minute.available else {
                throw URLError(.cannotParseResponse)
            }
            let snap = WeatherSnapshot(city: c, current: current, days: days, minute: minute,
                                       alerts: alerts, source: .official, fetchedAt: Date())
            snapshot = snap
            SharedStore.save(snap)
            SharedStore.reloadWidgets()
        } catch {
            lastError = "获取失败（\(error.localizedDescription)），请检查网络后下拉重试"
        }
        isLoading = false
    }

    /// 快照缺失或超过刷新间隔时刷新
    func refreshIfNeeded() async {
        if snapshot == nil || SharedStore.isStale(snapshot!) {
            await refresh()
        }
    }

    /// 自动定位并切换到所在贵州城市
    func autoLocate() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let c = try await LocationResolver.shared.resolveCurrentCity()
            if c.id == city.id {
                await refresh()
            } else {
                city = c // didSet 自动刷新
            }
        } catch {
            lastError = "定位失败：\(error.localizedDescription)"
            await refreshIfNeeded()
        }
    }

    // MARK: 10 分钟自动刷新（App 存活期间；后台由 BGTask + Widget 时间线接力）

    func startAutoRefresh() {
        autoTask?.cancel()
        autoTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(WeatherStore.refreshInterval * 1_000_000_000))
                guard !Task.isCancelled, let self else { break }
                await self.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        autoTask?.cancel()
        autoTask = nil
    }
}
