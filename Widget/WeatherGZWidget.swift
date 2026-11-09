import SwiftUI
import WidgetKit

@main
struct WeatherGZWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeatherMediumWidget()
        WeatherLockScreenWidget()
    }
}

// MARK: - 主屏中尺寸：当前天气、多久下雨、多久停、未来四天

struct WeatherMediumWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeatherGZMedium", provider: WeatherProvider()) { entry in
            MediumWidgetView(entry: entry)
                .widgetURL(URL(string: "weathergz://open"))
        }
        .configurationDisplayName("贵州天气 · 分钟级")
        .description("多久会下雨、多久会停、当前天气与未来四天")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 锁屏：几分钟后下雨、几分钟后停

struct WeatherLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeatherGZLock", provider: WeatherProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .widgetURL(URL(string: "weathergz://open"))
        }
        .configurationDisplayName("贵州天气 · 分钟级")
        .description("锁屏显示几分钟后下雨、几分钟后停")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - 时间线：每分钟刷新倒计时，10 分钟向系统请求新数据

struct WeatherEntry: TimelineEntry {
    let date: Date
    let snapshot: WeatherSnapshot?
}

struct WeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(WeatherProvider.entries().first ?? WeatherEntry(date: Date(), snapshot: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        let entries = WeatherProvider.entries()
        let next = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date()
        completion(Timeline(entries: entries, policy: .after(next)))
    }

    /// 未来 10 分钟逐分钟节点（倒计时每分钟走一格）
    static func entries() -> [WeatherEntry] {
        let snap = loadSnapshot()
        let now = Date()
        let cal = Calendar.current
        var out: [WeatherEntry] = []
        if let snap {
            for i in 0..<10 {
                guard let date = cal.nextDate(after: now,
                                              matching: DateComponents(minute: cal.component(.minute, from: now) + i),
                                              matchingPolicy: .nextTime) else { continue }
                out.append(WeatherEntry(date: date, snapshot: snap))
            }
        } else {
            out.append(WeatherEntry(date: now, snapshot: nil))
        }
        return out
    }

    static func loadSnapshot() -> WeatherSnapshot? {
        guard let snap = SharedStore.load() else { return nil }
        var s = snap
        s.isStale = SharedStore.isStale(s)
        return s
    }
}

// MARK: - 视图

extension View {
    /// iOS 17 起小组件需要 containerBackground；16.x 直接返回原视图
    @ViewBuilder
    func widgetContainerBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget, content: content)
        } else {
            self
        }
    }
}

struct MediumWidgetView: View {
    let entry: WeatherEntry

    private var background: LinearGradient {
        let snap = entry.snapshot
        return WeatherTheme.gradient(code: snap?.current?.weatherCode ?? "",
                                     raining: snap?.minute.isRaining(from: entry.date) ?? false,
                                     night: WeatherTheme.isNight(entry.date))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            // 右上角柔光点缀
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 150, height: 150)
                .blur(radius: 30)
                .offset(x: 180, y: -60)

            if let snap = entry.snapshot, snap.source != .none {
                content(snap)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "cloud.sun.fill").font(.title2).foregroundStyle(.white.opacity(0.9))
                    Text("等待首次更新").font(.caption.bold()).foregroundStyle(.white)
                    Text("打开一次 App 即可获取数据")
                        .font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .widgetContainerBackground { background }
    }

    private func content(_ snap: WeatherSnapshot) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // 左列：城市/预警、温度、风湿度、雨情、更新时间
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "location.north.line.fill")
                        .font(.system(size: 9)).opacity(0.8)
                    Text(snap.city.name)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 4)
                    if let alert = snap.alerts.first {
                        Text(alert.title)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(.white.opacity(0.22), in: Capsule())
                    }
                }

                Spacer(minLength: 2)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(snap.current?.tempC ?? 0)°")
                        .font(.system(size: 36, weight: .thin))
                    Text(snap.current?.weatherText ?? "")
                        .font(.system(size: 13)).opacity(0.9)
                }
                HStack(spacing: 8) {
                    Text("\(snap.current?.windDirec ?? "") \(snap.current?.windPower ?? "")")
                    if let h = snap.current?.humidity { Text("湿度 \(h)%") }
                }
                .font(.system(size: 11)).opacity(0.75)

                Spacer(minLength: 4)

                Text(RainMessage.text(snap.minute, from: entry.date))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Text(snap.fetchedAt.formatted(.dateTime.hour().minute()) + " 更新")
                        .font(.system(size: 9)).opacity(0.55)
                    if snap.isStale {
                        Text("· 打开 App 刷新").font(.system(size: 9)).foregroundStyle(.yellow.opacity(0.8))
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            // 右列：四天预报
            VStack(spacing: 8) {
                ForEach(snap.days.prefix(4)) { d in
                    HStack(spacing: 6) {
                        Text(WeatherText.weekday(d.date))
                            .font(.system(size: 11)).frame(width: 30, alignment: .leading)
                        Image(systemName: WIcon.symbol(code: d.dayWeatherCode))
                            .font(.system(size: 12)).frame(width: 20)
                        Text("\(d.highC)°")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(d.lowC)°")
                            .font(.system(size: 11)).opacity(0.55)
                    }
                    .foregroundStyle(.white)
                }
            }
            .padding(.top, 2)
        }
        .padding(12)
    }
}

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WeatherEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text(rainShort).font(.caption2.bold())
                Text(tempText).font(.caption2).foregroundStyle(.secondary)
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(rainLine).font(.caption).bold()
                Text("\(entry.snapshot?.city.name ?? "") · \(tempText) \(entry.snapshot?.current?.weatherText ?? "")")
                    .font(.caption2).foregroundStyle(.secondary)
                if let alert = entry.snapshot?.alerts.first {
                    Text(alert.title).font(.caption2).foregroundStyle(.orange).lineLimit(1)
                }
            }
        }
    }

    private var snap: WeatherSnapshot? { entry.snapshot }

    private var tempText: String {
        guard let c = snap?.current else { return "--°" }
        return "\(c.tempC)°"
    }

    private var rainShort: String {
        guard let m = snap?.minute, m.available else { return "无短临" }
        if m.isRaining(from: entry.date) {
            if let stop = m.minutesUntilStop(from: entry.date) { return "停\(stop)m" }
            return "雨中"
        }
        if let until = m.minutesUntilRain(from: entry.date) { return "\(until)m雨" }
        return "2h无雨"
    }

    private var rainLine: String {
        guard let m = snap?.minute, m.available else { return "分钟级降水暂不可用" }
        if m.isRaining(from: entry.date) {
            if let stop = m.minutesUntilStop(from: entry.date) { return "正在下雨 · \(stop) 分钟后停" }
            return "正在下雨 · 持续中"
        }
        if let until = m.minutesUntilRain(from: entry.date) { return "\(until) 分钟后开始下" }
        return "未来 2 小时无明显降水"
    }

    private var inlineText: String {
        guard let snap else { return "贵州天气 · 等待更新" }
        return "\(snap.city.name) \(tempText) \(rainShort)"
    }
}
