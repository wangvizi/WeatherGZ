import Foundation
import CoreLocation

enum LocationError: LocalizedError {
    case permissionDenied
    case timeout
    case noResult

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "定位权限被拒绝，请到 设置→隐私→定位服务 中开启"
        case .timeout: return "定位超时，请到开阔处重试"
        case .noResult: return "未能解析出所在贵州城市，已回退默认城市"
        }
    }
}

/// 定位 → 反查贵州城市：内置列表匹配 → toy1 搜索 → 最近城市兜底
final class LocationResolver: NSObject, CLLocationManagerDelegate {
    static let shared = LocationResolver()

    private let mgr = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var timeoutTask: Task<Void, Never>?

    private override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: 入口

    func resolveCurrentCity() async throws -> City {
        let coord = try await requestLocation()
        return await resolveCity(coord: coord)
    }

    // MARK: 请求一次定位

    private func requestLocation() async throws -> CLLocationCoordinate2D {
        let status = mgr.authorizationStatus
        if status == .denied || status == .restricted {
            throw LocationError.permissionDenied
        }
        return try await withCheckedThrowingContinuation { c in
            self.continuation = c
            self.startTimeout()
            if status == .notDetermined {
                mgr.requestWhenInUseAuthorization() // 授权回调里再 requestLocation
            } else {
                mgr.requestLocation()
            }
        }
    }

    private func startTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            if !Task.isCancelled { self?.fail(LocationError.timeout) }
        }
    }

    private func succeed(_ coord: CLLocationCoordinate2D) {
        timeoutTask?.cancel(); timeoutTask = nil
        continuation?.resume(returning: coord); continuation = nil
    }

    private func fail(_ error: Error) {
        timeoutTask?.cancel(); timeoutTask = nil
        continuation?.resume(throwing: error); continuation = nil
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        succeed(loc.coordinate)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        fail(error)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        if s == .authorizedWhenInUse || s == .authorizedAlways {
            if continuation != nil { manager.requestLocation() }
        } else if s == .denied || s == .restricted {
            fail(LocationError.permissionDenied)
        }
    }

    // MARK: 坐标 → 城市

    private func resolveCity(coord: CLLocationCoordinate2D) async -> City {
        // 1) 苹果反查地名
        var names: [String] = []
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        if let marks = try? await CLGeocoder().reverseGeocodeLocation(loc) {
            for m in marks {
                if let a = m.administrativeArea { names.append(a) }
                if let l = m.locality { names.append(l) }
                if let s = m.subLocality { names.append(s) }
            }
        }
        // 2) 内置贵州城市匹配（原名或去后缀名）
        for raw in names {
            for key in [raw, Self.trimSuffix(raw)] where !key.isEmpty {
                if let c = CityData.all.first(where: { $0.name == key || $0.name.hasPrefix(key) || key.hasPrefix($0.name) }) {
                    return c
                }
            }
        }
        // 3) toy1 官方搜索（仅贵州）
        let client = WeatherClient()
        for raw in names {
            let key = Self.trimSuffix(raw)
            guard !key.isEmpty else { continue }
            if let hits = try? await client.searchCities(keyword: key),
               let gz = hits.first(where: { $0.province.contains("贵州") }) {
                var c = City(id: gz.cityID, name: gz.name, city: gz.city, province: gz.province,
                             lat: coord.latitude, lon: coord.longitude)
                if let (la, lo) = await client.fetchCoords(name: gz.name, province: gz.province) {
                    c.lat = la; c.lon = lo
                }
                return c
            }
        }
        // 4) 最近的内置城市兜底
        return nearest(coord)
    }

    private func nearest(_ coord: CLLocationCoordinate2D) -> City {
        CityData.all.min { a, b in
            distance(coord, a) < distance(coord, b)
        } ?? CityData.defaultCity
    }

    private func distance(_ p: CLLocationCoordinate2D, _ c: City) -> Double {
        let dLat = (p.latitude - c.lat) * 111.0
        let dLon = (p.longitude - c.lon) * 111.0 * cos(p.latitude * .pi / 180)
        return dLat * dLat + dLon * dLon
    }

    private static func trimSuffix(_ s: String) -> String {
        var t = s
        for suf in ["布依族苗族自治州", "苗族侗族自治州", "仡佬族苗族自治县", "自治区", "自治州", "自治县", "地区", "新区", "市", "区", "县"] {
            if t.hasSuffix(suf), t.count > suf.count {
                t.removeLast(suf.count); break
            }
        }
        return t
    }
}
