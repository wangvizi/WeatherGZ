import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: WeatherStore
    @State private var showCityPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                if let snap = store.snapshot, snap.current != nil || !snap.days.isEmpty || snap.minute.available {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            header(snap)
                            if snap.minute.available { rainCard(snap) }
                            if !snap.days.isEmpty { daysCard(snap.days) }
                            if !snap.alerts.isEmpty { alertsCard(snap.alerts) }
                            footer(snap)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "cloud.sun.rain.fill")
                            .font(.system(size: 44)).foregroundStyle(.white.opacity(0.9))
                        Text(store.isLoading ? "正在获取数据…" : "等待首次更新")
                            .font(.title3.bold()).foregroundStyle(.white)
                        Text("仅贵州省城市 · 中国天气网官方 · 无需 Key")
                            .font(.footnote).foregroundStyle(.white.opacity(0.7))
                        if let err = store.lastError {
                            Text(err).font(.caption).foregroundStyle(.yellow)
                                .multilineTextAlignment(.center)
                        }
                        Button {
                            Task { await store.refresh() }
                        } label: {
                            Text("立即获取")
                                .font(.headline).foregroundStyle(.primary)
                                .padding(.horizontal, 22).padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                    .padding()
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCityPicker = true } label: {
                        Image(systemName: "location.circle.fill")
                            .font(.title3).foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .refreshable { await store.refresh() }
            .task { await store.refreshIfNeeded() }
            .sheet(isPresented: $showCityPicker) { CityPickerView() }
        }
    }

    // MARK: 天气渐变背景（复用 Shared/WeatherTheme）

    private var background: LinearGradient {
        let snap = store.snapshot
        return WeatherTheme.gradient(code: snap?.current?.weatherCode ?? "",
                                     raining: snap?.minute.isRaining() ?? false,
                                     night: WeatherTheme.isNight())
    }

    // MARK: 头部

    private func header(_ snap: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { showCityPicker = true } label: {
                HStack(spacing: 5) {
                    Text(snap.city.name == snap.city.city ? "\(snap.city.province)·\(snap.city.city)" : "\(snap.city.city) · \(snap.city.name)")
                        .font(.title2.bold())
                    Image(systemName: "chevron.down").font(.caption.bold())
                }
                .foregroundStyle(.white)
            }
            HStack(alignment: .top, spacing: 14) {
                Text("\(snap.current?.tempC ?? 0)°")
                    .font(.system(size: 76, weight: .thin))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text(snap.current?.weatherText ?? "")
                        .font(.title3).foregroundStyle(.white.opacity(0.95))
                    HStack(spacing: 10) {
                        if let h = snap.current?.humidity {
                            Label("\(h)%", systemImage: "humidity").font(.footnote)
                        }
                        Label("\(snap.current?.windDirec ?? "")\(snap.current?.windPower ?? "")", systemImage: "wind")
                            .font(.footnote)
                    }
                    .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                if let cur = snap.current {
                    Image(systemName: WIcon.symbol(code: cur.weatherCode))
                        .font(.system(size: 40, weight: .thin))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: 雨情卡（核心）

    private func rainCard(_ snap: WeatherSnapshot) -> some View {
        let m = snap.minute
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill").font(.caption).foregroundStyle(.cyan)
                Text("分钟级降水").font(.caption.bold()).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("起报 \(m.issuedAt?.formatted(.dateTime.hour().minute()) ?? "--")")
                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            Group {
                if m.isRaining() {
                    if let stop = m.minutesUntilStop() {
                        Text("正在下雨 · 约 \(stop) 分钟后停").font(.title3.bold())
                    } else {
                        Text("正在下雨 · 两小时内持续").font(.title3.bold())
                    }
                } else if let until = m.minutesUntilRain() {
                    Text("约 \(until) 分钟后开始下雨").font(.title3.bold())
                } else {
                    Text("未来 2 小时无明显降水").font(.title3.bold())
                }
            }
            .foregroundStyle(.white)

            if let msg = m.summary, !msg.isEmpty {
                Text(msg).font(.subheadline).foregroundStyle(.white.opacity(0.85))
            }

            RainBars(points: m.points).frame(height: 44).padding(.top, 2)
            HStack {
                Text("现在").font(.caption2).foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("2 小时后").font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: 逐天

    private func daysCard(_ days: [DayForecast]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("未来预报", systemImage: "calendar")
                .font(.caption.bold()).foregroundStyle(.white.opacity(0.8))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(days) { d in
                        VStack(spacing: 6) {
                            Text(WeatherText.weekday(d.date)).font(.caption).foregroundStyle(.white.opacity(0.75))
                            Image(systemName: WIcon.symbol(code: d.dayWeatherCode))
                                .font(.system(size: 22, weight: .thin)).foregroundStyle(.white)
                            Text(WeatherText.fromCode(d.dayWeatherCode))
                                .font(.caption2).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                            Text("\(d.highC)°").font(.subheadline.bold()).foregroundStyle(.white)
                            Text("\(d.lowC)°").font(.caption).foregroundStyle(.white.opacity(0.55))
                        }
                        .frame(width: 62)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            if store.city.id.count > 9 {
                Text("实况与预报来自所属区县").font(.caption2).foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(16)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: 预警

    private func alertsCard(_ alerts: [WeatherAlert]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(alerts, id: \.title) { a in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.caption)
                        Text(a.title).font(.subheadline.bold())
                    }
                    .foregroundStyle(.yellow)
                    Text(a.text).font(.caption).foregroundStyle(.white.opacity(0.8)).lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func footer(_ snap: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("中国天气网官方 · 更新 \(snap.fetchedAt.formatted(.dateTime.hour().minute())) · 每 10 分钟自动刷新")
                .font(.caption2).foregroundStyle(.white.opacity(0.5))
            Text("Build \(WeatherStore.buildTag)").font(.caption2).foregroundStyle(.white.opacity(0.3))
        }
        .padding(.top, 4)
    }
}

// MARK: - 2 小时降水柱状图

struct RainBars: View {
    let points: [MinutePoint]

    var body: some View {
        let now = Date()
        let visible = points.filter { $0.time >= now && $0.time <= now.addingTimeInterval(2 * 3600) }
        let maxP = max(0.5, visible.map(\.precipMM).max() ?? 0.5)
        return HStack(alignment: .bottom, spacing: 3) {
            if visible.isEmpty {
                ForEach(0..<20, id: \.self) { _ in
                    Capsule().fill(Color.white.opacity(0.15)).frame(maxWidth: .infinity)
                        .frame(height: 3)
                }
            } else {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, p in
                    Capsule()
                        .fill(p.precipMM >= 0.05
                             ? LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .top, endPoint: .bottom)
                             : LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(3, CGFloat(min(1.0, p.precipMM / maxP)) * 42))
                }
            }
        }
    }
}

// MARK: - 城市选择（仅贵州）

struct CityPickerView: View {
    @EnvironmentObject var store: WeatherStore
    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var results: [WeatherClient.SearchCity] = []
    @State private var searching = false
    @State private var searchError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("搜索贵州城市/区县", text: $keyword)
                            .autocorrectionDisabled()
                            .onSubmit { doSearch() }
                        if searching { ProgressView() }
                    }
                }
                if !results.isEmpty {
                    Section("搜索结果（仅贵州）") {
                        ForEach(results) { r in
                            button(City(id: r.cityID, name: r.name, city: r.city,
                                         province: r.province, lat: 0, lon: 0),
                                   subtitle: "\(r.province) · \(r.city)")
                        }
                    }
                }
                if let err = searchError {
                    Section { Text(err).font(.caption).foregroundStyle(.orange) }
                }
                Section("安顺（默认区域）") {
                    ForEach(CityData.anshun) { c in button(c, subtitle: c.displayName) }
                }
                Section("市州") {
                    ForEach(CityData.prefectures) { c in button(c, subtitle: c.displayName) }
                }
                Section("其他区县") {
                    ForEach(CityData.counties) { c in button(c, subtitle: c.displayName) }
                }
            }
            .navigationTitle("选择城市")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func button(_ city: City, subtitle: String) -> some View {
        Button {
            if CityData.find(id: city.id) != nil {
                store.city = CityData.find(id: city.id)!
                dismiss()
                return
            }
            // 搜索城市：解析坐标后再切换
            searching = true
            Task {
                var c = city
                if let (lat, lon) = await WeatherClient().fetchCoords(name: c.name, province: c.province) {
                    c.lat = lat; c.lon = lon
                } else {
                    c.lat = 26.6; c.lon = 106.7 // 贵州中心，短临仍可用
                }
                store.city = c
                searching = false
                dismiss()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name).font(.body)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if city.id == store.city.id || city.name == store.city.name {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private func doSearch() {
        let kw = keyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else { results = []; return }
        searching = true
        searchError = nil
        Task {
            let client = WeatherClient()
            do {
                let all = try await client.searchCities(keyword: kw)
                results = all.filter { $0.province.contains("贵州") }
                if results.isEmpty {
                    searchError = "仅支持贵州省城市，未找到「\(kw)」"
                }
            } catch {
                searchError = "搜索失败：\(error.localizedDescription)"
            }
            searching = false
        }
    }
}
