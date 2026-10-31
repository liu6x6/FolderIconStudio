import Foundation

enum SymbolRenderingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case monochrome
    case multicolor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monochrome: "单色"
        case .multicolor: "多彩"
        }
    }
}

struct SFSymbolCategory: Identifiable, Hashable {
    let id: String
    let displayName: String
}

struct SFSymbolCatalog {
    static let allCategoryID = "all"
    static let defaultCategoryID = "objectsandtools"
    static let shared = SFSymbolCatalog()

    let symbols: [String]
    let categories: [SFSymbolCategory]
    private let symbolsByCategory: [String: [String]]

    func symbols(in categoryID: String, matching query: String) -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = symbolsByCategory[categoryID] ?? []
        guard !trimmedQuery.isEmpty else { return candidates }
        return candidates.filter { $0.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    func symbolCount(in categoryID: String) -> Int {
        symbolsByCategory[categoryID]?.count ?? 0
    }

    private init() {
        let resource = Self.loadResource()
        symbols = resource.symbols

        let categoryIDs = Set(resource.categories.values.flatMap { $0 }).sorted()
        categories = [
            SFSymbolCategory(id: Self.allCategoryID, displayName: "全部")
        ] + categoryIDs.map {
            SFSymbolCategory(id: $0, displayName: Self.categoryDisplayName(for: $0))
        }

        var symbolsByCategory = [Self.allCategoryID: resource.symbols]
        for categoryID in categoryIDs {
            symbolsByCategory[categoryID] = resource.symbols.filter {
                resource.categories[$0]?.contains(categoryID) == true
            }
        }
        self.symbolsByCategory = symbolsByCategory
    }

    private static func loadResource() -> Resource {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "sf-symbols", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let resource = try? JSONDecoder().decode(Resource.self, from: data) else {
            return Resource(symbols: [], categories: [:])
        }
        return resource
    }

    private static func categoryDisplayName(for identifier: String) -> String {
        let names = [
            "accessibility": "辅助功能",
            "arrows": "箭头",
            "automotive": "汽车",
            "cameraandphotos": "相机与照片",
            "commerce": "商业",
            "communication": "通信",
            "connectivity": "连接",
            "devices": "设备",
            "editing": "编辑",
            "fitness": "健身",
            "gaming": "游戏",
            "health": "健康",
            "home": "家庭",
            "human": "人物",
            "indices": "索引",
            "keyboard": "键盘",
            "maps": "地图",
            "math": "数学",
            "media": "媒体",
            "multicolor": "多彩",
            "nature": "自然",
            "objectsandtools": "物体与工具",
            "privacyandsecurity": "隐私与安全",
            "shapes": "形状",
            "textformatting": "文本格式",
            "time": "时间",
            "transportation": "交通",
            "variable": "可变",
            "weather": "天气",
            "whatsnew": "新增"
        ]
        return names[identifier] ?? identifier
    }

    private struct Resource: Decodable {
        let symbols: [String]
        let categories: [String: [String]]
    }
}
