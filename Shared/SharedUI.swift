import SwiftUI

// MARK: - App 与小组件共用的视觉组件

enum WIcon {
    static func symbol(code: String) -> String {
        switch code {
        case "00": return "sun.max.fill"
        case "01": return "cloud.sun.fill"
        case "02": return "cloud.fill"
        case "03": return "cloud.rain.fill"
        case "04", "05": return "cloud.bolt.rain.fill"
        case "06": return "cloud.sleet.fill"
        case "07", "21": return "cloud.rain.fill"
        case "08", "22": return "cloud.drizzle.fill"
        case "09", "10", "11", "12", "23", "24", "25": return "cloud.heavyrain.fill"
        case "13", "15", "16", "27": return "cloud.snow.fill"
        case "14", "26": return "snowflake"
        case "17", "28": return "snowflake"
        case "18": return "cloud.fog.fill"
        case "19": return "cloud.sleet.fill"
        case "20", "30", "31": return "wind"
        case "29": return "sun.haze.fill"
        case "32", "53": return "cloud.haze.fill"
        default: return "questionmark"
        }
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

// MARK: 雨情一句话（App 与小组件共用）

enum RainMessage {
    static func text(_ m: MinuteForecast, from date: Date = Date()) -> String {
        guard m.available else { return "分钟级降水暂不可用" }
        if m.isRaining(from: date) {
            if let stop = m.minutesUntilStop(from: date) { return "正在下雨 · \(stop) 分钟后停" }
            return "正在下雨 · 持续中"
        }
        if let until = m.minutesUntilRain(from: date) { return "\(until) 分钟后开始下雨" }
        return "未来 2 小时无明显降水"
    }
}
