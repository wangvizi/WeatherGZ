import SwiftUI

// MARK: - App 与小组件共用的视觉组件

enum WIcon {
    static func symbol(code: String, night: Bool = false) -> String {
        switch code {
        case "00": return night ? "moon.stars.fill" : "sun.max.fill"
        case "01": return night ? "cloud.moon.fill" : "cloud.sun.fill"
        case "02": return "cloud.fill"
        case "03": return "cloud.rain.fill"
        case "04": return "cloud.bolt.fill"
        case "05": return "cloud.bolt.rain.fill"
        case "06": return "cloud.sleet.fill"
        case "07", "21": return "cloud.rain.fill"
        case "08", "22": return "cloud.drizzle.fill"
        case "09", "10", "11", "12", "23", "24", "25": return "cloud.heavyrain.fill"
        case "13", "15", "16", "27": return "cloud.snow.fill"
        case "14", "17", "26", "28": return "snowflake"
        case "18": return "cloud.fog.fill"
        case "19": return "cloud.sleet.fill"
        case "20", "30", "31": return "wind"
        case "29": return night ? "cloud.moon.fill" : "sun.haze.fill"
        case "32", "53": return "cloud.haze.fill"
        default: return "questionmark"
        }
    }
}

// MARK: 雨情时间线：多久下 / 多久变大 / 多久变小 / 多久停

enum RainTimeline {
    /// 6 分钟累计雨量分级：0 无 1 小雨 2 中雨 3 大雨 4 暴雨
    static func level(_ mm: Double) -> Int {
        if mm < 0.05 { return 0 }
        if mm < 2.5 { return 1 }
        if mm < 8 { return 2 }
        if mm < 16 { return 3 }
        return 4
    }

    static func levelName(_ l: Int) -> String {
        ["无雨", "小雨", "中雨", "大雨", "暴雨"][min(max(l, 0), 4)]
    }

    struct Event {
        let minutes: Int
        let text: String   // 已含"X分钟后…"
    }

    static func fmt(_ min: Int) -> String {
        if min < 60 { return "\(min) 分钟" }
        let h = min / 60, r = min % 60
        if r == 0 { return "\(h) 小时" }
        if h < 2 { return "\(h) 小时 \(r) 分" }
        return "\(h) 小时"
    }

    static func events(_ m: MinuteForecast, from date: Date = Date()) -> [Event] {
        guard m.available else { return [] }
        let pts = m.points.filter { $0.time >= date.addingTimeInterval(-180) }
        guard !pts.isEmpty else { return [] }
        let lv = pts.map { level($0.precipMM) }
        let minOf = { (i: Int) -> Int in max(0, Int(pts[i].time.timeIntervalSince(date) / 60)) }

        guard let s = lv.firstIndex(where: { $0 > 0 }) else { return [] }
        let rainingNow = lv[0] > 0
        var out: [Event] = []

        if !rainingNow {
            out.append(Event(minutes: minOf(s), text: "\(fmt(minOf(s)))后开始下\(levelName(lv[s]))"))
        }
        let base = rainingNow ? lv[0] : lv[s]

        // 变大：首个比当前强度高一档以上
        if let i = (s..<lv.count).first(where: { lv[$0] >= base + 1 }), i > (rainingNow ? 0 : s) {
            out.append(Event(minutes: minOf(i), text: "\(fmt(minOf(i)))后雨势变大，转\(levelName(lv[i]))"))
        }
        // 峰值
        var peak = s
        for i in (s..<lv.count) where lv[i] > lv[peak] { peak = i }
        // 变小：峰值后首次降档
        if peak + 1 < lv.count, let i = ((peak + 1)..<lv.count).first(where: { lv[$0] <= lv[peak] - 1 && lv[$0] > 0 }) {
            out.append(Event(minutes: minOf(i), text: "\(fmt(minOf(i)))后雨势变小，转\(levelName(lv[i]))"))
        }
        // 停：雨段后首个无雨
        if let i = ((peak)..<lv.count).first(where: { lv[$0] == 0 }) {
            out.append(Event(minutes: minOf(i), text: "\(fmt(minOf(i)))后雨停"))
        } else {
            out.append(Event(minutes: minOf(lv.count - 1), text: "\(fmt(minOf(lv.count - 1)))内不会停"))
        }
        return out
    }

    static func headline(_ m: MinuteForecast, from date: Date = Date()) -> String {
        guard m.available else { return "分钟级降水暂不可用" }
        if m.isRaining(from: date) { return "正在下雨" }
        if let u = m.minutesUntilRain(from: date) { return "\(fmt(u))后开始下雨" }
        return "未来 2 小时无明显降水"
    }
}

enum WeatherTheme {
    /// 按天气码/降雨/昼夜返回渐变背景
    static func gradient(code: String, raining: Bool, night: Bool) -> LinearGradient {
        let snow = ["13", "14", "15", "16", "17", "26", "27", "28"].contains(code)
        let thunder = ["04", "05"].contains(code)
        let fog = ["18", "29", "30", "31", "32", "53"].contains(code)

        let colors: [Color]
        if raining || thunder {
            colors = [Color(red: 0.22, green: 0.34, blue: 0.52), Color(red: 0.07, green: 0.11, blue: 0.22)]
        } else if snow {
            colors = [Color(red: 0.55, green: 0.65, blue: 0.78), Color(red: 0.20, green: 0.26, blue: 0.38)]
        } else if fog {
            colors = [Color(red: 0.45, green: 0.48, blue: 0.52), Color(red: 0.18, green: 0.20, blue: 0.24)]
        } else if code == "00" || code == "01" {
            colors = night
                ? [Color(red: 0.10, green: 0.14, blue: 0.30), Color(red: 0.02, green: 0.03, blue: 0.10)]
                : [Color(red: 0.36, green: 0.62, blue: 0.88), Color(red: 0.12, green: 0.28, blue: 0.55)]
        } else if code == "02" {
            colors = [Color(red: 0.40, green: 0.47, blue: 0.58), Color(red: 0.14, green: 0.17, blue: 0.26)]
        } else {
            colors = [Color(red: 0.30, green: 0.44, blue: 0.62), Color(red: 0.08, green: 0.13, blue: 0.26)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    static func isNight(_ date: Date = Date()) -> Bool {
        let h = Calendar.current.component(.hour, from: date)
        return h < 6 || h >= 19
    }
}

