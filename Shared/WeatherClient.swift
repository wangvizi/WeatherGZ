import Foundation

/// 中国天气网官方接口（零配置、无需 Key）：
/// - 实况：d1.weather.com.cn/sk_2d
/// - 逐天+预警：d1.weather.com.cn/weather_index
/// - 分钟级短临：mpf.weather.com.cn/mpf_v3/webgis/minute
/// - 城市搜索：toy1.weather.com.cn/search
public struct WeatherClient {
    public init() {}

    private var session: URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }

    // MARK: 底层：拉取文本并解析多个 "var NAME = {...};" 片段

    private func officialText(url: String, cityID: String) async throws -> String {
        guard let u = URL(string: url) else { throw URLError(.badURL) }
        var req = URLRequest(url: u)
        req.setValue("https://www.weather.com.cn/", forHTTPHeaderField: "Referer")
        req.setValue("city=\(cityID)", forHTTPHeaderField: "Cookie")
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        return String(decoding: data, as: UTF8.self)
    }

    /// 解析 JS 文本中所有顶层 `var name = {…}/[…]` 对象
    public static func parseJSVars(_ text: String) -> [String: Any] {
        let chars = Array(text)
        var out: [String: Any] = [:]
        var i = 0
        while i + 3 < chars.count {
            if chars[i] == "v", chars[i+1] == "a", chars[i+2] == "r", chars[i+3] == " " {
                var j = i + 4
                var name = ""
                while j < chars.count, chars[j] != "=" { name.append(chars[j]); j += 1 }
                name = name.trimmingCharacters(in: .whitespaces)
                j += 1
                while j < chars.count, chars[j] == " " { j += 1 }
                guard j < chars.count, chars[j] == "{" || chars[j] == "[" else { i += 1; continue }
                let open = chars[j]
                let close: Character = open == "{" ? "}" : "]"
                var depth = 0, k = j, inStr = false, esc = false
                while k < chars.count {
                    let c = chars[k]
                    if inStr {
                        if esc { esc = false }
                        else if c == "\\" { esc = true }
                        else if c == "\"" { inStr = false }
                    } else {
                        if c == "\"" { inStr = true }
                        else if c == open { depth += 1 }
                        else if c == close { depth -= 1; if depth == 0 { break } }
                    }
                    k += 1
                }
                if k < chars.count, depth == 0 {
                    let jsonStr = String(chars[j...k])
                    if let dd = jsonStr.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: dd) {
                        out[name] = obj
                    }
                }
                i = k + 1
            } else { i += 1 }
        }
        return out
    }

    /// dingzhi/alarm 变量名带城市 ID 后缀（如 alarmDZ101260307），按前缀查找
    private func findVar(_ vars: [String: Any], prefix: String) -> Any? {
        if let v = vars[prefix] { return v }
        if let key = vars.keys.first(where: { $0.hasPrefix(prefix) }) { return vars[key] }
        return nil
    }

    /// "d07"/"n02"/"d7" → "07"/"02"/"07"
    static func stripCode(_ s: String) -> String {
        guard let first = s.first, first == "d" || first == "n" else { return s }
        let rest = String(s.dropFirst())
        return rest.count == 1 ? "0" + rest : rest
    }

    // MARK: 实况

    public func fetchCurrent(cityID: String) async throws -> CurrentWeather? {
        let text = try await officialText(
            url: "https://d1.weather.com.cn/sk_2d/\(cityID).html?_=\(Int(Date().timeIntervalSince1970))",
            cityID: cityID)
        guard let sk = WeatherClient.parseJSVars(text)["dataSK"] as? [String: Any],
              let temp = Double(sk["temp"] as? String ?? "") else { return nil }
        let code = WeatherClient.stripCode(sk["weathercode"] as? String ?? "")
        return CurrentWeather(
            tempC: Int((temp * 10).rounded() / 10),
            weatherCode: code,
            weatherText: (sk["weather"] as? String) ?? WeatherText.fromCode(code),
            humidity: Int((sk["SD"] as? String ?? "").replacingOccurrences(of: "%", with: "")),
            windDirec: (sk["WD"] as? String) ?? "",
            windPower: (sk["WS"] as? String) ?? "",
            rainMM: Double(sk["rain"] as? String ?? ""),
            updatedAt: Date())
    }

    // MARK: 逐天 + 预警

    public func fetchDailyAndAlerts(cityID: String) async throws -> ([DayForecast], [WeatherAlert]) {
        let text = try await officialText(
            url: "https://d1.weather.com.cn/weather_index/\(cityID).html", cityID: cityID)
        let vars = WeatherClient.parseJSVars(text)
        let days = WeatherClient.parseDaily(vars["fc"] as? [String: Any])
        let alerts = WeatherClient.parseAlerts(findVar(vars, prefix: "alarmDZ") as? [String: Any])
        return (days, alerts)
    }

    public static func parseDaily(_ fc: [String: Any]?) -> [DayForecast] {
        guard let arr = fc?["f"] as? [[String: Any]] else { return [] }
        let fmt = DateFormatter()
        fmt.dateFormat = "MM/d"
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        var out: [DayForecast] = []
        for f in arr.prefix(5) {
            guard let fi = f["fi"] as? String, var date = fmt.date(from: fi) else { continue }
            if date < cal.date(byAdding: .day, value: -1, to: now)! {
                date = cal.date(byAdding: .year, value: 1, to: date)!
            }
            let df = cal.dateComponents([.year, .month, .day], from: date)
            let key = String(format: "%04d-%02d-%02d", df.year ?? 0, df.month ?? 0, df.day ?? 0)
            out.append(DayForecast(
                dateKey: key, date: date,
                highC: Int(f["fc"] as? String ?? "") ?? 0,
                lowC: Int(f["fd"] as? String ?? "") ?? 0,
                dayWeatherCode: stripCode(f["fa"] as? String ?? ""),
                nightWeatherCode: stripCode(f["fb"] as? String ?? ""),
                windDirecCode: (f["fe"] as? String) ?? "",
                windPower: (f["fg"] as? String) ?? "",
                precipProb: nil))
        }
        return out
    }

    public static func parseAlerts(_ alarm: [String: Any]?) -> [WeatherAlert] {
        guard let w = alarm?["w"] as? [[String: Any]] else { return [] }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return w.compactMap { a in
            guard let type = a["w5"] as? String, let level = a["w7"] as? String else { return nil }
            return WeatherAlert(title: "\(type)\(level)预警",
                                text: (a["w9"] as? String) ?? "",
                                issuedAt: fmt.date(from: (a["w8"] as? String) ?? ""))
        }
    }

    // MARK: 分钟级短临 MPF（times/values 平行数组，逐 6 分钟）

    public func fetchMinute(lat: Double, lon: Double) async throws -> MinuteForecast {
        let url = "http://mpf.weather.com.cn/mpf_v3/webgis/minute?lat=\(String(format: "%.4f", lat))&lon=\(String(format: "%.4f", lon))"
        let text = try await officialText(url: url, cityID: "")
        guard let obj = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              (obj["status"] as? String) == "true",
              let times = obj["times"] as? [String],
              let values = obj["values"] as? [Double] else {
            throw URLError(.cannotParseResponse)
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var points: [MinutePoint] = []
        for (i, t) in times.enumerated() where i < values.count {
            if let date = fmt.date(from: t) {
                points.append(MinutePoint(time: date, precipMM: values[i]))
            }
        }
        guard !points.isEmpty else { throw URLError(.cannotParseResponse) }
        return MinuteForecast(issuedAt: fmt.date(from: (obj["uptime"] as? String) ?? ""),
                              points: points, available: true, source: .official,
                              summary: obj["msg"] as? String)
    }

    // MARK: 城市搜索（toy1，ref 串以 ~ 分隔）

    public struct SearchCity: Identifiable, Hashable {
        public var id: String { cityID }
        public let cityID: String
        public let name: String
        public let city: String
        public let province: String
        public init(cityID: String, name: String, city: String, province: String) {
            self.cityID = cityID; self.name = name; self.city = city; self.province = province
        }
    }

    public func searchCities(keyword: String) async throws -> [SearchCity] {
        let kw = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let text = try await officialText(
            url: "https://toy1.weather.com.cn/search?cityname=\(kw)&type=1&_=\(Int(Date().timeIntervalSince1970))",
            cityID: "")
        let vars = WeatherClient.parseJSVars(text)
        var arr = (vars[""] as? [[String: Any]])
        if arr == nil {
            if let s = text.range(of: "["), let e = text.range(of: "]", range: s.upperBound..<text.endIndex) {
                let jsonStr = String(text[s.lowerBound...e.lowerBound])
                arr = (try? JSONSerialization.jsonObject(with: Data(jsonStr.utf8))) as? [[String: Any]]
            }
        }
        guard let list = arr else { return [] }
        return list.compactMap { item in
            guard let ref = item["ref"] as? String else { return nil }
            let f = ref.split(separator: "~", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 5, !f[0].isEmpty else { return nil }
            return SearchCity(cityID: f[0], name: f[2], city: f[4], province: f.last ?? "")
        }
    }

    // MARK: 坐标解析（仅为 MPF 短临提供经纬度，天气数据全部走官方接口）

    public func fetchCoords(name: String, province: String) async -> (Double, Double)? {
        let kw = (province + name).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        guard let u = URL(string: "https://geocoding-api.open-meteo.com/v1/search?count=1&language=zh&name=\(kw)") else { return nil }
        guard let (data, _) = try? await session.data(from: u),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = obj["results"] as? [[String: Any]],
              let first = results.first,
              let lat = first["latitude"] as? Double,
              let lon = first["longitude"] as? Double else { return nil }
        return (lat, lon)
    }
}
