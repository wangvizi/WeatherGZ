import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: WeatherStore
    @State private var showCityPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if let snap = store.snapshot {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            rainCard(snap)
                            if let cur = snap.current { currentCard(cur) }
                            if !snap.days.isEmpty { daysCard(snap.days) }
                            if !snap.alerts.isEmpty { alertsCard(snap.alerts) }
                            footerCard(snap)
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 12) {
                        placeholderCard()
                        if let err = store.lastError {
                            Text(err).font(.caption).foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                        }
                        Button {
                            Task { await store.refresh() }
                        } label: {
                            Label("立即获取", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(snap_title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showCityPicker = true } label: {
                        Label("切换城市", systemImage: "location.circle")
                    }
                }
            }
            .refreshable { await store.refresh() }
            .task { await store.refreshIfNeeded() }
            .overlay {
                if store.isLoading && store.snapshot != nil {
                    ProgressView().padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .sheet(isPresented: $showCityPicker) { CityPickerView() }
        }
    }

    private var snap_title: String {
        store.snapshot?.city.displayName ?? store.city.displayName
    }

    // MARK: 核心：多久下雨 / 多久停

    private func rainCard(_ snap: WeatherSnapshot) -> some View {
        let m = snap.minute
        return VStack(alignment: .leading, spacing: 6) {
            if m.available {
                if m.isRaining() {
                    if let stop = m.minutesUntilStop() {
                        Text("正在下雨 · \(stop) 分钟后停").font(.title3.bold())
                    } else {
                        Text("正在下雨 · 两小时内持续").font(.title3.bold())
                    }
                } else if let until = m.minutesUntilRain() {
                    Text("\(until) 分钟后开始下雨").font(.title3.bold())
                    Text("至少还要 \(m.minutesOfNoRain() ?? until) 分钟无明显降水")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("未来 2 小时无明显降水").font(.title3.bold())
                }
                if let msg = m.summary, !msg.isEmpty {
                    Text(msg).font(.subheadline).foregroundStyle(.secondary)
                }
                Text("中国天气网官方 · MPF 短临 · 起报 \(m.issuedAt?.formatted(.dateTime.hour().minute()) ?? "--")")
                    .font(.caption2).foregroundStyle(.tertiary)
            } else {
                Text("分钟级降水暂不可用").font(.title3)
                Text("下拉重试或检查网络").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func currentCard(_ cur: CurrentWeather) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(cur.tempC)°").font(.system(size: 52, weight: .thin))
                Text(cur.weatherText).font(.headline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let h = cur.humidity { Text("湿度 \(h)%").font(.subheadline) }
                Text("\(cur.windDirec) \(cur.windPower)").font(.subheadline)
                if let r = cur.rainMM, r > 0 { Text("降水 \(String(format: "%.1f", r)) mm").font(.subheadline) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func daysCard(_ days: [DayForecast]) -> some View {
        VStack(spacing: 8) {
            ForEach(days) { d in
                HStack {
                    Text(WeatherText.weekday(d.date) + " " + d.date.formatted(.dateTime.month().day()))
                        .font(.subheadline).frame(width: 110, alignment: .leading)
                    Text(WeatherText.fromCode(d.dayWeatherCode))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(d.lowC)° / \(d.highC)°").font(.subheadline.monospacedDigit())
                    Text(d.windPower.isEmpty ? "" : "\(d.windPower)级")
                        .font(.caption).foregroundStyle(.tertiary).frame(width: 56, alignment: .trailing)
                }
                if d.id != days.last?.id { Divider() }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func alertsCard(_ alerts: [WeatherAlert]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(alerts, id: \.title) { a in
                VStack(alignment: .leading, spacing: 2) {
                    Text("⚠️ \(a.title)").font(.subheadline.bold()).foregroundStyle(.orange)
                    Text(a.text).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func footerCard(_ snap: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("数据源：中国天气网官方 · 更新时间 \(snap.fetchedAt.formatted(.dateTime.hour().minute())) · 每 10 分钟自动刷新")
                .font(.caption2).foregroundStyle(.secondary)
            if snap.isStale { Text("数据可能已过期").font(.caption2).foregroundStyle(.orange) }
            Text("Build \(WeatherStore.buildTag)").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func placeholderCard() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.sun").font(.largeTitle).foregroundStyle(.secondary)
            Text(store.isLoading ? "正在获取数据…" : "等待首次更新").font(.headline)
            Text("打开 App 自动获取 · 仅贵州省城市 · 无需任何 Key")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                if city.id == store.city.id {
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
