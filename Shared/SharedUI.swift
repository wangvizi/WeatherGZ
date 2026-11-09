import SwiftUI

// MARK: - App 与小组件共用的视觉组件

// MARK: 手绘矢量天气图标（App 与小组件共用，替代 SF Symbols）

struct WeatherGlyph: View {
    private enum Cat {
        case clear, partly, cloudy, rain, heavy, thunder, sleet, snow, fog, dust
    }

    private let cat: Cat
    private let night: Bool
    private let tint: Color

    init(code: String, night: Bool = false, tint: Color = .white) {
        self.night = night
        self.tint = tint
        switch code {
        case "00": cat = .clear
        case "01": cat = .partly
        case "02": cat = .cloudy
        case "03", "07", "08", "21", "22": cat = .rain
        case "09", "10", "11", "12", "23", "24", "25": cat = .heavy
        case "04", "05": cat = .thunder
        case "06", "19": cat = .sleet
        case "13", "14", "15", "16", "17", "26", "27", "28": cat = .snow
        case "18", "32", "53": cat = .fog
        case "20", "29", "30", "31": cat = .dust
        default: cat = .cloudy
        }
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack { layer(s) }
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func cloud(_ s: CGFloat, dy: CGFloat = 0) -> some View {
        ZStack {
            Circle().fill(tint).frame(width: 0.44*s, height: 0.44*s).offset(x: -0.17*s, y: -0.05*s + dy)
            Circle().fill(tint).frame(width: 0.56*s, height: 0.56*s).offset(x: 0.10*s, y: -0.13*s + dy)
            RoundedRectangle(cornerRadius: 0.16*s).fill(tint)
                .frame(width: 0.92*s, height: 0.36*s).offset(y: 0.10*s + dy)
        }
    }

    private func sun(_ s: CGFloat, r: CGFloat, rays: Int) -> some View {
        ZStack {
            Circle().fill(tint).frame(width: 0.44*r, height: 0.44*r)
            ForEach(0..<rays, id: \.self) { i in
                Capsule().fill(tint).frame(width: 0.06*r, height: 0.16*r)
                    .offset(y: -0.36*r)
                    .rotationEffect(.degrees(Double(i) * 360.0 / Double(rays)))
            }
        }
    }

    private func moon(_ s: CGFloat) -> some View {
        Path { p in
            p.addArc(center: CGPoint(x: 0.52*s, y: 0.5*s), radius: 0.36*s,
                     startAngle: .degrees(70), endAngle: .degrees(290), clockwise: false)
            p.addArc(center: CGPoint(x: 0.70*s, y: 0.5*s), radius: 0.28*s,
                     startAngle: .degrees(290), endAngle: .degrees(70), clockwise: true)
            p.closeSubpath()
        }
        .fill(tint)
    }

    private func drop(_ s: CGFloat, x: CGFloat, y: CGFloat, h: CGFloat) -> some View {
        Capsule().fill(tint).frame(width: 0.075*s, height: h)
            .rotationEffect(.degrees(15)).offset(x: x, y: y)
    }

    private func flake(_ s: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(tint).frame(width: 0.05*s, height: 0.2*s)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
        }
        .frame(width: 0.22*s, height: 0.22*s)
        .offset(x: x, y: y)
    }

    private func bolt(_ s: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0.56*s, y: 0.40*s))
            p.addLine(to: CGPoint(x: 0.34*s, y: 0.70*s))
            p.addLine(to: CGPoint(x: 0.49*s, y: 0.70*s))
            p.addLine(to: CGPoint(x: 0.38*s, y: 0.96*s))
            p.addLine(to: CGPoint(x: 0.68*s, y: 0.62*s))
            p.addLine(to: CGPoint(x: 0.53*s, y: 0.62*s))
            p.addLine(to: CGPoint(x: 0.64*s, y: 0.40*s))
            p.closeSubpath()
        }
        .fill(tint)
    }

    private func lines(_ s: CGFloat, widths: [CGFloat]) -> some View {
        VStack(spacing: 0.13*s) {
            ForEach(0..<widths.count, id: \.self) { i in
                Capsule().fill(tint).frame(width: widths[i]*s, height: 0.09*s)
            }
        }
    }

    @ViewBuilder
    private func layer(_ s: CGFloat) -> some View {
        switch cat {
        case .clear:
            if night { moon(s) } else { sun(s, r: s, rays: 8) }
        case .partly:
            ZStack {
                sun(0.6*s, r: 0.6*s, rays: 6).offset(x: 0.22*s, y: -0.2*s)
                cloud(s, dy: 0.1*s)
            }
        case .cloudy:
            cloud(s)
        case .rain:
            ZStack {
                cloud(s, dy: -0.16*s)
                drop(s, x: -0.2*s, y: 0.32*s, h: 0.18*s)
                drop(s, x: 0.02*s, y: 0.36*s, h: 0.2*s)
                drop(s, x: 0.24*s, y: 0.32*s, h: 0.18*s)
            }
        case .heavy:
            ZStack {
                cloud(s, dy: -0.18*s)
                drop(s, x: -0.24*s, y: 0.32*s, h: 0.24*s)
                drop(s, x: -0.06*s, y: 0.36*s, h: 0.26*s)
                drop(s, x: 0.12*s, y: 0.32*s, h: 0.24*s)
                drop(s, x: 0.28*s, y: 0.36*s, h: 0.22*s)
            }
        case .thunder:
            ZStack {
                cloud(s, dy: -0.22*s)
                bolt(s)
            }
        case .sleet:
            ZStack {
                cloud(s, dy: -0.16*s)
                drop(s, x: -0.16*s, y: 0.32*s, h: 0.18*s)
                flake(s, x: 0.14*s, y: 0.36*s)
            }
        case .snow:
            ZStack {
                cloud(s, dy: -0.16*s)
                flake(s, x: -0.22*s, y: 0.36*s)
                flake(s, x: 0.02*s, y: 0.4*s)
                flake(s, x: 0.24*s, y: 0.36*s)
            }
        case .fog:
            lines(s, widths: [0.8, 0.6, 0.8, 0.5])
        case .dust:
            lines(s, widths: [0.85, 0.6, 0.8])
        }
    }
}

// MARK: 雨丝纹理（背景点缀）

struct RainStreaks: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<16, id: \.self) { i in
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 1.2, height: CGFloat(10 + (i * 7) % 12))
                        .rotationEffect(.degrees(20))
                        .position(x: geo.size.width * CGFloat((i * 37) % 100) / 100,
                                  y: geo.size.height * CGFloat((i * 53) % 100) / 100)
                }
            }
        }
        .allowsHitTesting(false)
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

