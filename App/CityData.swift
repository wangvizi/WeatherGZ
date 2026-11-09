import Foundation

/// 内置城市：仅贵州省（安顺为默认区域）。ID 为中央气象台编码，经 toy1 接口实测校准。
public enum CityData {
    public static let defaultCity = City(id: "101260307", name: "西秀区", city: "安顺", province: "贵州",
                                         lat: 26.2467, lon: 105.9472)

    public static let anshun: [City] = [
        City(id: "101260307", name: "西秀区", city: "安顺", province: "贵州", lat: 26.2467, lon: 105.9472),
        City(id: "101260304", name: "平坝区", city: "安顺", province: "贵州", lat: 26.4050, lon: 106.2550),
        City(id: "101260302", name: "普定县", city: "安顺", province: "贵州", lat: 26.3070, lon: 105.7460),
        City(id: "101260303", name: "镇宁", city: "安顺", province: "贵州", lat: 26.0600, lon: 105.7700),
        City(id: "101260305", name: "关岭", city: "安顺", province: "贵州", lat: 25.9500, lon: 105.6200),
        City(id: "101260306", name: "紫云", city: "安顺", province: "贵州", lat: 25.7500, lon: 106.0800),
    ]

    public static let prefectures: [City] = [
        City(id: "101260101", name: "贵阳", city: "贵阳", province: "贵州", lat: 26.6470, lon: 106.6302),
        City(id: "101260201", name: "遵义", city: "遵义", province: "贵州", lat: 27.7258, lon: 106.9270),
        City(id: "101260803", name: "六盘水", city: "六盘水", province: "贵州", lat: 26.5920, lon: 104.8300),
        City(id: "101260701", name: "毕节", city: "毕节", province: "贵州", lat: 27.3027, lon: 105.2828),
        City(id: "101260601", name: "铜仁", city: "铜仁", province: "贵州", lat: 27.7183, lon: 109.1895),
        City(id: "101260401", name: "都匀", city: "黔南", province: "贵州", lat: 26.2580, lon: 107.5170),
        City(id: "101260501", name: "凯里", city: "黔东南", province: "贵州", lat: 26.5830, lon: 107.9830),
        City(id: "101260901", name: "兴义", city: "黔西南", province: "贵州", lat: 25.0880, lon: 104.8970),
    ]

    public static let counties: [City] = [
        City(id: "101260108", name: "清镇", city: "贵阳", province: "贵州", lat: 26.5580, lon: 106.4700),
        City(id: "101260107", name: "修文", city: "贵阳", province: "贵州", lat: 26.8390, lon: 106.5870),
        City(id: "101260106", name: "开阳", city: "贵阳", province: "贵州", lat: 27.0560, lon: 106.9670),
        City(id: "101260105", name: "息烽", city: "贵阳", province: "贵州", lat: 27.0930, lon: 106.7400),
        City(id: "101260704", name: "威宁", city: "毕节", province: "贵州", lat: 26.8570, lon: 104.2470),
        City(id: "101260702", name: "赫章", city: "毕节", province: "贵州", lat: 27.1110, lon: 104.9440),
    ]

    public static var all: [City] { anshun + prefectures + counties }

    public static func find(id: String) -> City? { all.first { $0.id == id } }
}
