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

    var body: some View {
        if let snap = entry.snapshot, snap.source != .none {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snap.city.name).font(.caption).foregroundStyle(.secondary)
                    Text("\(snap.current?.tempC ?? 0)°")
                        .font(.system(size: 34, weight: .light))
                    Text(snap.current?.weatherText ?? "").font(.caption)
                    Text(snap.fetchedAt.formatted(.dateTime.hour().minute()) + " 更新")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .frame(width: 84, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    minuteLine(snap)
                    HStack(spacing: 10) {
                        ForEach(snap.days.prefix(4)) { d in
                            VStack(spacing: 2) {
                                Text(WeatherText.weekday(d.date)).font(.caption2).foregroundStyle(.secondary)
                                Text("\(d.lowC)°/\(d.highC)°").font(.caption2.monospacedDigit())
                            }
                        }
                    }
                    if let alert = snap.alerts.first {
                        Text(alert.title).font(.caption2).lineLimit(1).foregroundStyle(.orange)
                    }
                    if snap.isStale {
                        Text("数据可能已过期 · 打开 App 刷新").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            }
            .padding(12)
            .widgetContainerBackground { Color.clear }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "cloud.sun").font(.title2).foregroundStyle(.secondary)
                Text("等待首次更新").font(.caption.bold())
                Text("打开一次 App 即可获取数据")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetContainerBackground { Color.clear }
        }
    }

    @ViewBuilder
    private func minuteLine(_ snap: WeatherSnapshot) -> some View {
        let m = snap.minute
        if m.available {
            if m.isRaining(from: entry.date) {
                if let stop = m.minutesUntilStop(from: entry.date) {
                    Text("正在下雨 · \(stop) 分钟后停").font(.subheadline.bold())
                } else {
                    Text("正在下雨 · 持续中").font(.subheadline.bold())
                }
            } else if let until = m.minutesUntilRain(from: entry.date) {
                Text("\(until) 分钟后开始下").font(.subheadline.bold())
                Text("至少还要 \(m.minutesOfNoRain(from: entry.date) ?? until) 分钟无明显降水")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("未来 2 小时无明显降水").font(.subheadline.bold())
            }
            Text("中国天气网官方 · MPF 短临")
                .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
        } else {
            Text("分钟级降水暂不可用").font(.subheadline)
        }
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
