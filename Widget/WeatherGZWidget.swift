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
                .overlay(RainStreaks().opacity(entry.snap.minute.isRaining(from: entry.date) ? 0.10 : 0))
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
        HStack(alignment: .top, spacing: 8) {
            // 左列
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Text(snap.city.name)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(.white.opacity(0.16), in: Capsule())
                    if let alert = snap.alerts.first {
                        Text(alert.title)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.orange.opacity(0.85), in: Capsule())
                    }
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 2)

                HStack(alignment: .center, spacing: 6) {
                    Text("\(snap.current?.tempC ?? 0)°")
                        .font(.system(size: 38, weight: .thin))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snap.current?.weatherText ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .opacity(0.9)
                        Text("\(snap.current?.windDirec ?? "") \(snap.current?.windPower ?? "") · 湿度 \(snap.current?.humidity ?? 0)%")
                            .font(.system(size: 10))
                            .opacity(0.6)
                    }
                    Spacer(minLength: 0)
                    WeatherGlyph(code: snap.current?.weatherCode ?? "",
                                 night: WeatherTheme.isNight(entry.date))
                        .frame(width: 34, height: 34)
                }

                Spacer(minLength: 5)

                Text(RainTimeline.headline(snap.minute, from: entry.date))
                    .font(.system(size: 13, weight: .bold))
                let compact = RainTimeline.compactText(snap.minute, from: entry.date)
                if !compact.isEmpty {
                    Text(compact)
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.85)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 3)

                Text(snap.fetchedAt.formatted(.dateTime.hour().minute()) + " 更新"
                     + (snap.isStale ? " · 打开 App 刷新" : ""))
                    .font(.system(size: 9))
                    .foregroundStyle(snap.isStale ? AnyShapeStyle(Color.yellow.opacity(0.9))
                                                  : AnyShapeStyle(Color.white.opacity(0.5)))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // 右列：四天预报（固定列宽 + 分隔线）
            VStack(spacing: 0) {
                ForEach(Array(snap.days.prefix(4).enumerated()), id: \.element.id) { idx, d in
                    HStack(spacing: 0) {
                        Text(WeatherText.dateLabel(d))
                            .font(.system(size: idx == 0 ? 11 : 10,
                                          weight: idx == 0 ? .semibold : .regular))
                            .frame(width: 32, alignment: .leading)
                        WeatherGlyph(code: d.dayWeatherCode)
                            .frame(width: 16, height: 16)
                            .opacity(0.9)
                        Spacer(minLength: 3)
                        Text("\(d.highC)°")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 24, alignment: .trailing)
                        Text("\(d.lowC)°")
                            .font(.system(size: 11))
                            .opacity(0.5)
                            .frame(width: 24, alignment: .trailing)
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    if idx < 3 {
                        Rectangle().fill(.white.opacity(0.12)).frame(height: 0.5)
                    }
                }
            }
            .frame(width: 106)
        }
        .padding(12)
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

// MARK: - iOS 16/17 背景兼容

extension View {
    @ViewBuilder
    func widgetBG<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(content: content)
        } else {
            widgetBackground(content: content)
        }
    }
}
