import SwiftUI
import WidgetKit

// MARK: - 小组件入口

@main
struct WeatherGZWidgetBundle: WidgetBundle {
    var body: some Widget {
        GZMediumWidget()
        GZLockWidget()
    }
}

// MARK: - 时间线：逐 6 分钟节点走倒计时，每 10 分钟向系统请求新数据

struct GZEntry: TimelineEntry {
    let date: Date
    let snap: WeatherSnapshot
}

struct GZProvider: TimelineProvider {
    private func fresh() -> WeatherSnapshot {
        guard var s = SharedStore.load() else { return .empty }
        s.isStale = SharedStore.isStale(s)
        return s
    }

    func placeholder(in context: Context) -> GZEntry {
        GZEntry(date: Date(), snap: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (GZEntry) -> Void) {
        completion(GZEntry(date: Date(), snap: fresh()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GZEntry>) -> Void) {
        let snap = fresh()
        let now = Date()
        var entries: [GZEntry] = []
        for i in 0..<20 {
            entries.append(GZEntry(date: now.addingTimeInterval(TimeInterval(i * 6 * 60)), snap: snap))
        }
        let cal = Calendar(identifier: .gregorian)
        let mins = cal.component(.minute, from: now)
        let next = cal.date(byAdding: .minute, value: (10 - mins % 10) + 1, to: now)
            ?? now.addingTimeInterval(660)
        completion(Timeline(entries: entries, policy: .after(next)))
    }
}

// MARK: - 主屏中尺寸

struct GZMediumWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeatherGZMedium", provider: GZProvider()) { entry in
            GZMediumView(entry: entry)
                .widgetURL(URL(string: "weathergz://open"))
        }
        .configurationDisplayName("贵州天气 · 分钟级")
        .description("多久下雨、多久变大变小、多久停，当前天气与未来四天")
        .supportedFamilies([.systemMedium])
    }
}

struct GZMediumView: View {
    let entry: GZEntry

    var body: some View {
        Group {
            if entry.snap.current == nil && !entry.snap.minute.available {
                emptyView
            } else {
                content(entry.snap)
            }
        }
        .widgetBG {
            WeatherTheme.gradient(code: entry.snap.current?.weatherCode ?? "",
                                  raining: entry.snap.minute.isRaining(from: entry.date),
                                  night: WeatherTheme.isNight(entry.date))
                .overlay(RainDrops().opacity(entry.snap.minute.isRaining(from: entry.date) ? 0.5 : 0.12))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            WeatherGlyph(code: "02")
                .frame(width: 30, height: 30).opacity(0.85)
            Text("等待首次更新").font(.system(size: 12)).opacity(0.7)
            Text("打开一次 App 即可").font(.system(size: 10)).opacity(0.5)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(_ snap: WeatherSnapshot) -> some View {
        HStack(alignment: .top, spacing: 4) {
            // 左列（参考版式：城市行 / 大温度+风湿度+大图标 / 粗体雨情两行 / 更新时间）
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "location.north.line.fill")
                        .font(.system(size: 9))
                        .opacity(0.7)
                    Text(snap.city.name)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 4)
                    if let alert = snap.alerts.first {
                        Text(alert.title)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(.white.opacity(0.18), in: Capsule())
                    }
                }

                Spacer(minLength: 6)

                HStack(alignment: .center, spacing: 4) {
                    Text("\(snap.current?.tempC ?? 0)°")
                        .font(.system(size: 44, weight: .medium))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(snap.current?.windDirec ?? "") \(snap.current?.windPower ?? "")")
                            .font(.system(size: 11))
                            .opacity(0.8)
                        Text("湿度 \(snap.current?.humidity ?? 0)%")
                            .font(.system(size: 11))
                            .opacity(0.8)
                    }
                    .padding(.top, 6)
                    Spacer(minLength: 2)
                    WeatherGlyph(code: snap.current?.weatherCode ?? "",
                                 night: WeatherTheme.isNight(entry.date))
                        .frame(width: 40, height: 40)
                        .padding(.trailing, 2)
                }

                Spacer(minLength: 8)

                Text(rainNarrative(snap))
                    .font(.system(size: 12.5, weight: .bold))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                Text("更新时间  \(snap.fetchedAt.formatted(.dateTime.hour().minute()))"
                     + (snap.isStale ? " · 打开 App 刷新" : ""))
                    .font(.system(size: 9))
                    .foregroundStyle(snap.isStale ? AnyShapeStyle(Color.yellow.opacity(0.9))
                                                  : AnyShapeStyle(Color.white.opacity(0.5)))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.trailing, 2)

            // 右列：四天预报，四行均匀铺满整个高度（首行对齐城市行、末行对齐更新时间）
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(snap.days.prefix(4).enumerated()), id: \.element.id) { idx, d in
                    if idx > 0 { Spacer(minLength: 0) }
                    HStack(spacing: 0) {
                        Text(WeatherText.dayLabel(d, index: idx))
                            .font(.system(size: 11))
                            .frame(width: 30, alignment: .leading)
                        WeatherGlyph(code: d.dayWeatherCode)
                            .frame(width: 18, height: 18)
                            .opacity(0.95)
                        Spacer(minLength: 3)
                        Text("\(d.highC)°")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 28, alignment: .trailing)
                        Text("\(d.lowC)°")
                            .font(.system(size: 12))
                            .opacity(0.5)
                            .frame(width: 26, alignment: .trailing)
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(minWidth: 112, maxWidth: 112, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(12)
    }

    /// 参考图式叙述："38 分钟后雨渐小，转为中雨，不过 58 分钟后雨会再次变大"
    private func rainNarrative(_ snap: WeatherSnapshot) -> String {
        let m = snap.minute
        guard m.available else { return "打开 App 获取分钟级降水" }
        let evs = RainTimeline.events(m, from: entry.date)
        if evs.isEmpty { return RainTimeline.headline(m, from: entry.date) }
        let parts = evs.prefix(2).map { $0.text }
        if parts.count == 2 { return parts[0] + "，不过 " + parts[1] }
        return parts[0]
    }
}

// MARK: - 锁屏小组件

struct GZLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeatherGZLock", provider: GZProvider()) { entry in
            GZLockView(entry: entry)
                .widgetURL(URL(string: "weathergz://open"))
        }
        .configurationDisplayName("贵州天气 · 锁屏")
        .description("锁屏显示多久下雨、多久停")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct GZLockView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GZEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.snap.city.name) \(entry.snap.current?.tempC ?? 0)° \(entry.snap.current?.weatherText ?? "") · \(rainLine)")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text("\(entry.snap.current?.tempC ?? 0)°")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(shortRain)
                    .font(.system(size: 8))
                    .lineLimit(1)
            }
        default:
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(entry.snap.city.name)
                        .font(.system(size: 10, weight: .semibold))
                    Spacer()
                    Text("\(entry.snap.current?.tempC ?? 0)° \(entry.snap.current?.weatherText ?? "")")
                        .font(.system(size: 10))
                }
                Text(rainLine)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text(entry.snap.fetchedAt.formatted(.dateTime.hour().minute()) + " 更新")
                    .font(.system(size: 8)).opacity(0.5)
            }
        }
    }

    private var rainLine: String {
        let m = entry.snap.minute
        guard m.available else { return "打开 App 获取数据" }
        let h = RainTimeline.headline(m, from: entry.date)
        if let stop = m.minutesUntilStop(from: entry.date) {
            return "\(h) · \(RainTimeline.fmt(stop))后停"
        }
        if let start = m.minutesUntilRain(from: entry.date) {
            return "\(h) · \(RainTimeline.fmt(start))后开始下"
        }
        return h
    }

    private var shortRain: String {
        let m = entry.snap.minute
        guard m.available else { return "--" }
        if m.isRaining(from: entry.date) { return "雨中" }
        if let s = m.minutesUntilRain(from: entry.date) { return "\(s)分后雨" }
        return "无雨"
    }
}

// MARK: - 玻璃水珠质感（参考图背景）

struct RainDrops: View {
    // 归一化坐标 (x, y, 半径比例)，固定种子保证每次渲染一致
    private static let drops: [(CGFloat, CGFloat, CGFloat)] = [
        (0.06, 0.12, 0.030), (0.14, 0.55, 0.022), (0.22, 0.20, 0.016), (0.30, 0.78, 0.028),
        (0.38, 0.35, 0.014), (0.45, 0.62, 0.024), (0.52, 0.10, 0.018), (0.58, 0.88, 0.020),
        (0.66, 0.42, 0.026), (0.72, 0.15, 0.015), (0.80, 0.70, 0.022), (0.86, 0.30, 0.018),
        (0.93, 0.58, 0.026), (0.10, 0.85, 0.016), (0.34, 0.05, 0.020), (0.62, 0.72, 0.014),
        (0.88, 0.92, 0.018), (0.04, 0.45, 0.012), (0.48, 0.28, 0.012), (0.76, 0.52, 0.012),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                ForEach(0 ..< Self.drops.count, id: \.self) { i in
                    let d = Self.drops[i]
                    let r = d.2 * min(w, h)
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                        )
                        .overlay(
                            Circle().fill(Color.white.opacity(0.30))
                                .frame(width: r * 0.35, height: r * 0.35)
                                .offset(x: -r * 0.25, y: -r * 0.3)
                        )
                        .frame(width: r * 2, height: r * 2)
                        .offset(x: d.0 * w - r, y: d.1 * h - r)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - iOS 16/17 背景兼容

extension View {
    @ViewBuilder
    func widgetBG<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget, content: content)
        } else {
            self.background(content())
        }
    }
}
