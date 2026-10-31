import AppKit
import SwiftUI

struct ColorValue: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    static let blue = ColorValue(red: 0.21, green: 0.48, blue: 0.94)
    static let purple = ColorValue(red: 0.54, green: 0.31, blue: 0.86)
    static let pink = ColorValue(red: 0.91, green: 0.27, blue: 0.53)
    static let orange = ColorValue(red: 0.94, green: 0.47, blue: 0.17)
    static let green = ColorValue(red: 0.16, green: 0.62, blue: 0.39)

    var hexRGB: String {
        String(
            format: "#%02X%02X%02X",
            Int((red.clampedToUnit * 255).rounded()),
            Int((green.clampedToUnit * 255).rounded()),
            Int((blue.clampedToUnit * 255).rounded())
        )
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    func mixed(with color: ColorValue, fraction: Double) -> ColorValue {
        let clampedFraction = fraction.clampedToUnit
        return ColorValue(
            red: red + (color.red - red) * clampedFraction,
            green: green + (color.green - green) * clampedFraction,
            blue: blue + (color.blue - blue) * clampedFraction,
            alpha: alpha + (color.alpha - alpha) * clampedFraction
        )
    }

    var lighter: ColorValue {
        mixed(with: ColorValue(red: 1, green: 1, blue: 1, alpha: alpha), fraction: 0.35)
    }

    var darker: ColorValue {
        mixed(with: ColorValue(red: 0, green: 0, blue: 0, alpha: alpha), fraction: 0.35)
    }

    init(_ color: Color) {
        self.init(NSColor(color))
    }

    init(_ color: NSColor) {
        let resolved = color.usingColorSpace(.sRGB) ?? .systemBlue
        red = Double(resolved.redComponent)
        green = Double(resolved.greenComponent)
        blue = Double(resolved.blueComponent)
        alpha = Double(resolved.alphaComponent)
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

private extension Double {
    var clampedToUnit: Double {
        min(max(self, 0), 1)
    }
}

struct FolderColorPreset: Identifiable, Equatable, Sendable {
    let name: String
    let color: ColorValue

    var id: String { name }

    static let all: [FolderColorPreset] = [
        FolderColorPreset(name: "海洋蓝", color: ColorValue(red: 0.16, green: 0.50, blue: 0.85)),
        FolderColorPreset(name: "天际蓝", color: ColorValue(red: 0.23, green: 0.67, blue: 0.88)),
        FolderColorPreset(name: "青绿色", color: ColorValue(red: 0.12, green: 0.63, blue: 0.61)),
        FolderColorPreset(name: "森林绿", color: ColorValue(red: 0.18, green: 0.55, blue: 0.32)),
        FolderColorPreset(name: "柠檬黄", color: ColorValue(red: 0.89, green: 0.69, blue: 0.18)),
        FolderColorPreset(name: "琥珀橙", color: ColorValue(red: 0.92, green: 0.47, blue: 0.15)),
        FolderColorPreset(name: "珊瑚红", color: ColorValue(red: 0.86, green: 0.30, blue: 0.28)),
        FolderColorPreset(name: "莓果粉", color: ColorValue(red: 0.78, green: 0.29, blue: 0.52)),
        FolderColorPreset(name: "紫罗兰", color: ColorValue(red: 0.48, green: 0.34, blue: 0.79)),
        FolderColorPreset(name: "石墨灰", color: ColorValue(red: 0.30, green: 0.35, blue: 0.42)),
        FolderColorPreset(name: "午夜蓝", color: ColorValue(red: 0.14, green: 0.29, blue: 0.49)),
        FolderColorPreset(name: "冰川青", color: ColorValue(red: 0.25, green: 0.69, blue: 0.78)),
        FolderColorPreset(name: "鼠尾草绿", color: ColorValue(red: 0.39, green: 0.61, blue: 0.49)),
        FolderColorPreset(name: "青柠绿", color: ColorValue(red: 0.59, green: 0.69, blue: 0.18)),
        FolderColorPreset(name: "酒红色", color: ColorValue(red: 0.61, green: 0.20, blue: 0.29)),
        FolderColorPreset(name: "板岩蓝", color: ColorValue(red: 0.29, green: 0.38, blue: 0.53)),
        FolderColorPreset(name: "玫瑰金", color: ColorValue(red: 0.82, green: 0.53, blue: 0.46)),
        FolderColorPreset(name: "薄荷绿", color: ColorValue(red: 0.33, green: 0.78, blue: 0.64))
    ]
}

enum FolderBaseIcon: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case open
    case group

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: "标准"
        case .open: "打开"
        case .group: "群组"
        }
    }

    var resourceName: String {
        switch self {
        case .standard: "GenericFolderIcon"
        case .open: "OpenFolderIcon"
        case .group: "GroupFolder"
        }
    }
}

struct FolderStyle: Codable, Equatable, Sendable {
    var color: ColorValue = .blue
    var opacity: Double = 1
    var baseIcon: FolderBaseIcon = .standard

    init(color: ColorValue = .blue, opacity: Double = 1, baseIcon: FolderBaseIcon = .standard) {
        self.color = color
        self.opacity = opacity
        self.baseIcon = baseIcon
    }

    private enum CodingKeys: String, CodingKey {
        case color
        case opacity
        case baseIcon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = try container.decodeIfPresent(ColorValue.self, forKey: .color) ?? .blue
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        baseIcon = try container.decodeIfPresent(FolderBaseIcon.self, forKey: .baseIcon) ?? .standard
    }
}

struct LayerTransform: Codable, Equatable, Sendable {
    var centerX: Double
    var centerY: Double
    var scale: Double
    var rotationDegrees: Double
    var opacity: Double
    var isVisible: Bool
    var isLocked: Bool

    init(
        centerX: Double = 0.5,
        centerY: Double = 0.53,
        scale: Double = 0.45,
        rotationDegrees: Double = 0,
        opacity: Double = 1,
        isVisible: Bool = true,
        isLocked: Bool = false
    ) {
        self.centerX = centerX
        self.centerY = centerY
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.opacity = opacity
        self.isVisible = isVisible
        self.isLocked = isLocked
    }

    private enum CodingKeys: String, CodingKey {
        case centerX, centerY, scale, rotationDegrees, opacity, isVisible, isLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        centerX = try container.decodeIfPresent(Double.self, forKey: .centerX) ?? 0.5
        centerY = try container.decodeIfPresent(Double.self, forKey: .centerY) ?? 0.53
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 0.45
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }
}

struct SymbolLayer: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var symbolName: String
    var color: ColorValue
    var renderingMode: SymbolRenderingMode
    var transform: LayerTransform

    init(
        id: UUID = UUID(),
        symbolName: String,
        color: ColorValue = ColorValue(red: 1, green: 1, blue: 1),
        renderingMode: SymbolRenderingMode = .monochrome,
        transform: LayerTransform = LayerTransform()
    ) {
        self.id = id
        self.symbolName = symbolName
        self.color = color
        self.renderingMode = renderingMode
        self.transform = transform
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case symbolName
        case color
        case renderingMode
        case transform
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        symbolName = try container.decode(String.self, forKey: .symbolName)
        color = try container.decodeIfPresent(ColorValue.self, forKey: .color) ?? ColorValue(red: 1, green: 1, blue: 1)
        renderingMode = try container.decodeIfPresent(SymbolRenderingMode.self, forKey: .renderingMode) ?? .monochrome
        transform = try container.decodeIfPresent(LayerTransform.self, forKey: .transform) ?? LayerTransform()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(symbolName, forKey: .symbolName)
        try container.encode(color, forKey: .color)
        try container.encode(renderingMode, forKey: .renderingMode)
        try container.encode(transform, forKey: .transform)
    }
}

struct TextLayer: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var text: String
    var color: ColorValue
    var fontFamily: String?
    var fontWeight: TextFontWeight
    var isItalic: Bool
    var transform: LayerTransform

    init(
        id: UUID = UUID(),
        text: String,
        color: ColorValue = ColorValue(red: 1, green: 1, blue: 1),
        fontFamily: String? = nil,
        fontWeight: TextFontWeight = .bold,
        isItalic: Bool = false,
        transform: LayerTransform = LayerTransform()
    ) {
        self.id = id
        self.text = text
        self.color = color
        self.fontFamily = fontFamily
        self.fontWeight = fontWeight
        self.isItalic = isItalic
        self.transform = transform
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case color
        case fontFamily
        case fontWeight
        case isItalic
        case transform
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        color = try container.decodeIfPresent(ColorValue.self, forKey: .color) ?? ColorValue(red: 1, green: 1, blue: 1)
        fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily)
        fontWeight = try container.decodeIfPresent(TextFontWeight.self, forKey: .fontWeight) ?? .bold
        isItalic = try container.decodeIfPresent(Bool.self, forKey: .isItalic) ?? false
        transform = try container.decodeIfPresent(LayerTransform.self, forKey: .transform) ?? LayerTransform()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(color, forKey: .color)
        try container.encodeIfPresent(fontFamily, forKey: .fontFamily)
        try container.encode(fontWeight, forKey: .fontWeight)
        try container.encode(isItalic, forKey: .isItalic)
        try container.encode(transform, forKey: .transform)
    }
}

enum TextFontWeight: String, Codable, CaseIterable, Identifiable, Sendable {
    case regular
    case medium
    case semibold
    case bold
    case heavy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .regular: "常规"
        case .medium: "中等"
        case .semibold: "半粗"
        case .bold: "粗体"
        case .heavy: "特粗"
        }
    }

    var appKitWeight: Int {
        switch self {
        case .regular: 5
        case .medium: 6
        case .semibold: 8
        case .bold: 9
        case .heavy: 11
        }
    }
}

struct ImageLayer: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var filePath: String
    var transform: LayerTransform

    init(id: UUID = UUID(), filePath: String, transform: LayerTransform = LayerTransform()) {
        self.id = id
        self.filePath = filePath
        self.transform = transform
    }
}

enum IconLayer: Codable, Equatable, Identifiable, Sendable {
    case symbol(SymbolLayer)
    case emoji(TextLayer)
    case text(TextLayer)
    case image(ImageLayer)

    var id: UUID {
        switch self {
        case .symbol(let layer): layer.id
        case .emoji(let layer), .text(let layer): layer.id
        case .image(let layer): layer.id
        }
    }

    var title: String {
        switch self {
        case .symbol(let layer): "Symbol: \(layer.symbolName)"
        case .emoji(let layer): "Emoji: \(layer.text)"
        case .text(let layer): "Text: \(layer.text)"
        case .image: "Image"
        }
    }

    var transform: LayerTransform {
        get {
            switch self {
            case .symbol(let layer): return layer.transform
            case .emoji(let layer), .text(let layer): return layer.transform
            case .image(let layer): return layer.transform
            }
        }
        set {
            switch self {
            case .symbol(var layer):
                layer.transform = newValue
                self = .symbol(layer)
            case .emoji(var layer):
                layer.transform = newValue
                self = .emoji(layer)
            case .text(var layer):
                layer.transform = newValue
                self = .text(layer)
            case .image(var layer):
                layer.transform = newValue
                self = .image(layer)
            }
        }

    }

    var iconName: String {
        switch self {
        case .symbol: "sparkles"
        case .emoji: "face.smiling"
        case .text: "textformat"
        case .image: "photo"
        }
    }
}

struct IconDocument: Codable, Equatable, Sendable {
    var folderStyle = FolderStyle()
    var layers: [IconLayer] = []
}

struct Preset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var category: String
    var document: IconDocument

    init(id: UUID = UUID(), name: String, category: String = "未分类", document: IconDocument) {
        self.id = id
        self.name = name
        self.category = category
        self.document = document
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, category, document
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "未分类"
        document = try container.decode(IconDocument.self, forKey: .document)
    }
}
