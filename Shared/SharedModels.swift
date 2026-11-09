import Foundation

// MARK: - 城市

/// 可选择的观测城市/区县（中央气象台城市 ID 体系）
public struct City: Identifiable, Codable, Hashable {
    public var id: String          // 城市 ID，如 "101260307"
    public var name: String        // 区县名，如 "西秀区"
    public var city: String        // 市，如 "安顺"
    public var province: String    // 省，如 "贵州"
    public var lat: Double
    public var lon: Double

    public init(id: String, name: String, city: String, province: String, lat: Double, lon: Double) {
        self.id = id; self.name = name; self.city = city
        self.province = province; self.lat = lat; self.lon = lon
    }

    public var displayName: String {
        if name == city { return "\(province) · \(city)" }
        return "\(province) · \(city) · \(name)"
    }
}

// MARK: - 数据来源

public enum DataSourceKind: String, Codable {
    case official   // 中国天气网官方（零配置）
    case none
}

// MARK: - 分钟级降水

public struct MinutePoint: Codable, Hashable {
    public var time: Date
    public var precipMM: Double

    public init(time: Date, precipMM: Double) {
        self.time = time; self.precipMM = precipMM
    }
}

/// 分钟级短临预报结论（未来 2 小时）
public struct MinuteForecast: Codable, Hashable {
    public var issuedAt: Date?
    public var points: [MinutePoint]
    public var available: Bool
    public var source: DataSourceKind
    /// 官方 msg 文案，如"小雨还会继续2小时哦"
    public var summary: String?

    public init(issuedAt: Date? = nil, points: [MinutePoint] = [], available: Bool = false,
                source: DataSourceKind = .none, summary: String? = nil) {
        self.issuedAt = issuedAt; self.points = points
        self.available = available; self.source = source; self.summary = summary
    }

    /// 从 from 起：多少分钟后开始下雨（nil = 未来 2 小时无明显降水）
    public func minutesUntilRain(from date: Date = Date()) -> Int? {
        for p in points where p.time >= date && p.precipMM >= 0.05 {
            return max(0, Int(p.time.timeIntervalSince(date) / 60))
        }
        return nil
    }

    /// 若当前正在下雨：多少分钟后雨停（nil = 两小时内不停）
    public func minutesUntilStop(from date: Date = Date()) -> Int? {
        guard isRaining(from: date) else { return nil }
        for p in points where p.time >= date && p.precipMM < 0.05 {
            return max(0, Int(p.time.timeIntervalSince(date) / 60))
        }
        return nil
    }

    public func isRaining(from date: Date = Date()) -> Bool {
        points.first(where: { abs($0.time.timeIntervalSince(date)) < 60 })?.precipMM ?? 0 >= 0.05
    }

    /// 若当前无雨：至少还要多少分钟无明显降水
    public func minutesOfNoRain(from date: Date = Date()) -> Int? {
        if isRaining(from: date) { return nil }
        return minutesUntilRain(from: date) ?? 120
    }
}

// MARK: - 逐日预报

public struct DayForecast: Codable, Hashable, Identifiable {
    public var id: String { dateKey }
    public var dateKey: String
    public var date: Date
    public var highC: Int
    public var lowC: Int
    public var dayWeatherCode: String
    public var nightWeatherCode: String
    public var windDirecCode: String
    public var windPower: String
    public var precipProb: Int?

    public init(dateKey: String, date: Date, highC: Int, lowC: Int,
                dayWeatherCode: String, nightWeatherCode: String,
                windDirecCode: String, windPower: String, precipProb: Int? = nil) {
        self.dateKey = dateKey; self.date = date
        self.highC = highC; self.lowC = lowC
        self.dayWeatherCode = dayWeatherCode; self.nightWeatherCode = nightWeatherCode
        self.windDirecCode = windDirecCode; self.windPower = windPower
        self.precipProb = precipProb
    }
}

// MARK: - 气象预警

public struct WeatherAlert: Codable, Hashable {
    public var title: String
    public var text: String
    public var issuedAt: Date?
    public init(title: String, text: String, issuedAt: Date? = nil) {
        self.title = title; self.text = text; self.issuedAt = issuedAt
    }
}

// MARK: - 实况

public struct CurrentWeather: Codable, Hashable {
    public var tempC: Int
    public var weatherCode: String
    public var weatherText: String
    public var humidity: Int?
    public var windDirec: String
    public var windPower: String
    public var rainMM: Double?
    public var updatedAt: Date

    public init(tempC: Int, weatherCode: String = "", weatherText: String = "",
                humidity: Int? = nil, windDirec: String = "", windPower: String = "",
                rainMM: Double? = nil, updatedAt: Date = Date()) {
        self.tempC = tempC; self.weatherCode = weatherCode; self.weatherText = weatherText
        self.humidity = humidity; self.windDirec = windDirec
        self.windPower = windPower; self.rainMM = rainMM; self.updatedAt = updatedAt
    }
}

// MARK: - 快照（App ↔ Widget 共享）

public struct WeatherSnapshot: Codable {
    public var city: City
    public var current: CurrentWeather?
    public var days: [DayForecast]
    public var minute: MinuteForecast
    public var alerts: [WeatherAlert]
    public var source: DataSourceKind
    public var fetchedAt: Date
    public var isStale: Bool

    public init(city: City, current: CurrentWeather?, days: [DayForecast], minute: MinuteForecast,
                alerts: [WeatherAlert], source: DataSourceKind, fetchedAt: Date, isStale: Bool = false) {
        self.city = city; self.current = current; self.days = days
        self.minute = minute; self.alerts = alerts; self.source = source
        self.fetchedAt = fetchedAt; self.isStale = isStale
    }

    public static let empty = WeatherSnapshot(
        city: City(id: "101260307", name: "西秀区", city: "安顺", province: "贵州", lat: 26.2467, lon: 105.9472),
        current: nil, days: [], minute: MinuteForecast(), alerts: [],
        source: .none, fetchedAt: .distantPast, isStale: true)
}

// MARK: - 展示辅助

public enum WeatherText {
    public static let codeTable: [String: String] = [
        "00": "晴", "01": "多云", "02": "阴天", "03": "阵雨", "04": "雷阵雨",
        "05": "雷阵雨冰雹", "06": "雨夹雪", "07": "小雨", "08": "中雨", "09": "大雨",
        "10": "暴雨", "11": "大暴雨", "12": "特大暴雨", "13": "阵雪", "14": "小雪",
        "15": "中雪", "16": "大雪", "17": "暴雪", "18": "雾", "19": "冻雨",
        "20": "沙尘暴", "21": "小到中雨", "22": "中到大雨", "23": "大到暴雨",
        "24": "暴雨到大暴雨", "25": "大暴雨到特大暴雨", "26": "小到中雪",
        "27": "中到大雪", "28": "大到暴雪", "29": "浮尘", "30": "扬沙",
        "31": "强沙尘暴", "32": "霾", "53": "霾", "99": ""
    ]
    public static func fromCode(_ code: String) -> String { codeTable[code] ?? "" }

    public static let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    public static func weekday(_ date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        return weekdayNames[cal.component(.weekday, from: date) - 1]
    }
}
