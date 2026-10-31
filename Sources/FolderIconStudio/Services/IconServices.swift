import AppKit
import SwiftUI

enum FolderIconError: LocalizedError {
    case invalidFolder(URL)
    case unsupportedFolder(URL)
    case folderNotWritable(URL)
    case invalidIconFile(URL)
    case renderFailed
    case finderUpdateFailed(URL)
    case exportFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .invalidFolder(let url):
            "“\(url.lastPathComponent)”不是普通本地文件夹。"
        case .unsupportedFolder(let url):
            "“\(url.lastPathComponent)”是应用程序或系统包目录，不能修改其图标。"
        case .folderNotWritable(let url):
            "没有“\(url.lastPathComponent)”的修改权限。请选择你有写入权限的文件夹。"
        case .invalidIconFile(let url):
            "“\(url.lastPathComponent)”不是可读取的 ICNS 图标文件。"
        case .renderFailed:
            "无法生成文件夹图标。"
        case .finderUpdateFailed(let url):
            "无法为“\(url.lastPathComponent)”更新 Finder 图标。请检查文件夹权限。"
        case .exportFailed(let url, let error):
            "无法导出到“\(url.lastPathComponent)”: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class IconRenderer {
    static let shared = IconRenderer()
    private var folderImageCache: [FolderBaseIcon: NSImage] = [:]
    private let renderedImageCache = NSCache<NSString, NSImage>()

    func render(document: IconDocument, pixelSize: CGFloat = 1024) throws -> NSImage {
        guard pixelSize > 0 else { throw FolderIconError.renderFailed }
        let cacheKey = try renderCacheKey(document: document, pixelSize: pixelSize)
        if let cachedImage = renderedImageCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }

        let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
        image.lockFocus()
        defer { image.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high
        let bounds = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        NSColor.clear.setFill()
        bounds.fill()

        drawFolderBase(in: bounds, style: document.folderStyle)

        for layer in document.layers {
            if layer.transform.isVisible {
                draw(layer: layer, in: bounds)
            }
        }
        renderedImageCache.setObject(image, forKey: cacheKey as NSString)
        return image
    }

    func clearRenderedImageCache() {
        renderedImageCache.removeAllObjects()
    }

    private func renderCacheKey(document: IconDocument, pixelSize: CGFloat) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let documentData = try encoder.encode(document)
        return "\(Int(pixelSize.rounded()))-\(documentData.base64EncodedString())"
    }

    private func drawFolderBase(in bounds: NSRect, style: FolderStyle) {
        guard let folderImage = folderImage(for: style.baseIcon) else {
            NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)?.draw(in: bounds)
            return
        }

        folderImage.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: CGFloat(style.opacity))
        if let context = NSGraphicsContext.current?.cgContext,
           let mask = folderImage.cgImage(forProposedRect: nil, context: NSGraphicsContext.current, hints: nil) {
            context.saveGState()
            context.clip(to: bounds, mask: mask)
            style.color.nsColor.withAlphaComponent(CGFloat(style.opacity)).setFill()
            bounds.fill(using: .color)
            context.restoreGState()
        }
    }

    private func folderImage(for baseIcon: FolderBaseIcon) -> NSImage? {
        if let cachedImage = folderImageCache[baseIcon] {
            return cachedImage
        }
        let coreTypesURL = URL(fileURLWithPath: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/\(baseIcon.resourceName).icns")
        if let image = NSImage(contentsOf: coreTypesURL) {
            folderImageCache[baseIcon] = image
            return image
        }
        let fallback = NSImage(named: NSImage.Name("NSFolder"))
        if let fallback {
            folderImageCache[baseIcon] = fallback
        }
        return fallback
    }

    private func draw(layer: IconLayer, in bounds: NSRect) {
        let transform = layer.transform
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: bounds.width * transform.centerX, y: bounds.height * transform.centerY)
        context.rotate(by: transform.rotationDegrees * .pi / 180)

        let side = bounds.width * transform.scale
        let rect = NSRect(x: -side / 2, y: -side / 2, width: side, height: side)
        let opacity = CGFloat(transform.opacity)
        switch layer {
        case .symbol(let symbol):
            var configuration = NSImage.SymbolConfiguration(pointSize: side, weight: .semibold)
            if symbol.renderingMode == .monochrome {
                configuration = configuration.applying(
                    NSImage.SymbolConfiguration(paletteColors: [symbol.color.nsColor])
                )
            } else {
                configuration = configuration
                    .applying(
                        NSImage.SymbolConfiguration(
                            paletteColors: [
                                symbol.color.nsColor,
                                symbol.color.lighter.nsColor,
                                symbol.color.darker.nsColor
                            ]
                        )
                    )
            }
            let symbolImage = NSImage(systemSymbolName: symbol.symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration)
            if symbol.renderingMode == .monochrome {
                symbolImage?.draw(in: rect, from: .zero, operation: .sourceOver, fraction: opacity)
            } else {
                symbolImage?.isTemplate = false
                symbolImage?.draw(in: rect, from: .zero, operation: .sourceOver, fraction: opacity)
            }
        case .emoji(let text):
            let font = NSFont.systemFont(ofSize: side * 0.72, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: text.color.nsColor.withAlphaComponent(text.color.nsColor.alphaComponent * opacity)
            ]
            let string = NSAttributedString(string: text.text, attributes: attributes)
            let size = string.size()
            string.draw(at: NSPoint(x: -size.width / 2, y: -size.height / 2))
        case .text(let text):
            let font = font(for: text, size: side * 0.72)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: text.color.nsColor.withAlphaComponent(text.color.nsColor.alphaComponent * opacity)
            ]
            let string = NSAttributedString(string: text.text, attributes: attributes)
            let size = string.size()
            string.draw(at: NSPoint(x: -size.width / 2, y: -size.height / 2))
        case .image(let image):
            NSImage(contentsOf: URL(fileURLWithPath: image.filePath))?.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: opacity
            )
        }
    }

    private func font(for textLayer: TextLayer, size: CGFloat) -> NSFont {
        guard let fontFamily = textLayer.fontFamily, !fontFamily.isEmpty else {
            let font = NSFont.systemFont(ofSize: size, weight: systemWeight(for: textLayer.fontWeight))
            return textLayer.isItalic
                ? NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                : font
        }
        let traits: NSFontTraitMask = textLayer.isItalic ? .italicFontMask : []
        if let font = NSFontManager.shared.font(
            withFamily: fontFamily,
            traits: traits,
            weight: textLayer.fontWeight.appKitWeight,
            size: size
        ) {
            return font
        }

        let fallback = NSFont(name: fontFamily, size: size)
            ?? NSFont.systemFont(ofSize: size, weight: systemWeight(for: textLayer.fontWeight))
        return textLayer.isItalic
            ? NSFontManager.shared.convert(fallback, toHaveTrait: .italicFontMask)
            : fallback
    }

    private func systemWeight(for fontWeight: TextFontWeight) -> NSFont.Weight {
        switch fontWeight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }
}

@MainActor
final class FinderIconService {
    func apply(document: IconDocument, to folderURL: URL) throws {
        try validate(folderURL: folderURL)
        let image = try IconRenderer.shared.render(document: document)
        guard NSWorkspace.shared.setIcon(image, forFile: folderURL.path, options: []) else {
            throw FolderIconError.finderUpdateFailed(folderURL)
        }
    }

    func applyICNS(at iconURL: URL, to folderURL: URL) throws {
        try validate(folderURL: folderURL)
        guard Self.isICNSFile(iconURL),
              let image = NSImage(contentsOf: iconURL) else {
            throw FolderIconError.invalidIconFile(iconURL)
        }
        guard NSWorkspace.shared.setIcon(image, forFile: folderURL.path, options: []) else {
            throw FolderIconError.finderUpdateFailed(folderURL)
        }
    }

    func clearIcon(from folderURL: URL) throws {
        try validate(folderURL: folderURL)
        guard NSWorkspace.shared.setIcon(nil, forFile: folderURL.path, options: []) else {
            throw FolderIconError.finderUpdateFailed(folderURL)
        }
    }

    func validate(folderURL url: URL) throws {
        guard url.isFileURL, url.path != "/" else {
            throw FolderIconError.invalidFolder(url)
        }

        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isApplicationKey])
        guard values.isDirectory == true else {
            throw FolderIconError.invalidFolder(url)
        }

        let packageExtensions: Set<String> = ["app", "bundle", "framework", "plugin", "pkg", "kext", "mdimporter", "xpc"]
        if values.isPackage == true || values.isApplication == true || packageExtensions.contains(url.pathExtension.lowercased()) {
            throw FolderIconError.unsupportedFolder(url)
        }

        guard FileManager.default.isWritableFile(atPath: url.path) else {
            throw FolderIconError.folderNotWritable(url)
        }
    }

    nonisolated static func isICNSFile(_ url: URL) -> Bool {
        url.isFileURL && url.pathExtension.caseInsensitiveCompare("icns") == .orderedSame
    }
}

@MainActor
final class IconExportService {
    func exportPNG(
        document: IconDocument,
        to url: URL,
        pixelSize: CGFloat = 1024,
        transparentBackground: Bool = true
    ) throws {
        do {
            try pngData(
                document: document,
                pixelSize: pixelSize,
                transparentBackground: transparentBackground
            ).write(to: url, options: .atomic)
        } catch {
            throw FolderIconError.exportFailed(url, error)
        }
    }

    func exportPNGs(
        document: IconDocument,
        to directory: URL,
        pixelSizes: [Int],
        transparentBackground: Bool
    ) throws -> [URL] {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return try pixelSizes.map { pixelSize in
                let url = directory.appendingPathComponent("FolderIcon-\(pixelSize).png")
                try pngData(
                    document: document,
                    pixelSize: CGFloat(pixelSize),
                    transparentBackground: transparentBackground
                ).write(to: url, options: .atomic)
                return url
            }
        } catch {
            throw FolderIconError.exportFailed(directory, error)
        }
    }

    private func pngData(
        document: IconDocument,
        pixelSize: CGFloat,
        transparentBackground: Bool
    ) throws -> Data {
        let image = try IconRenderer.shared.render(document: document, pixelSize: pixelSize)
        let exportImage: NSImage
        if transparentBackground {
            exportImage = image
        } else {
            exportImage = NSImage(size: image.size)
            exportImage.lockFocus()
            NSColor.white.setFill()
            NSRect(origin: .zero, size: image.size).fill()
            image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
            exportImage.unlockFocus()
        }
        guard let tiff = exportImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw FolderIconError.renderFailed
        }
        return data
    }

    func exportICNS(document: IconDocument, to url: URL) throws {
        let fileManager = FileManager.default
        let iconsetURL = fileManager.temporaryDirectory
            .appendingPathComponent("FolderIconStudio-\(UUID().uuidString).iconset", isDirectory: true)
        defer { try? fileManager.removeItem(at: iconsetURL) }

        do {
            try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
            let variants: [(String, CGFloat)] = [
                ("icon_16x16.png", 16),
                ("icon_16x16@2x.png", 32),
                ("icon_32x32.png", 32),
                ("icon_32x32@2x.png", 64),
                ("icon_128x128.png", 128),
                ("icon_128x128@2x.png", 256),
                ("icon_256x256.png", 256),
                ("icon_256x256@2x.png", 512),
                ("icon_512x512.png", 512),
                ("icon_512x512@2x.png", 1024)
            ]
            for (name, pixelSize) in variants {
                let image = try IconRenderer.shared.render(document: document, pixelSize: pixelSize)
                guard let tiff = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let data = bitmap.representation(using: .png, properties: [:]) else {
                    throw FolderIconError.renderFailed
                }
                try data.write(to: iconsetURL.appendingPathComponent(name), options: .atomic)
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
            process.arguments = ["-c", "icns", iconsetURL.path, "-o", url.path]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw FolderIconError.renderFailed
            }
        } catch {
            throw FolderIconError.exportFailed(url, error)
        }
    }
}

@MainActor
final class PresetStore: ObservableObject {
    @Published private(set) var presets: [Preset] = []
    private let defaultsKey = "savedPresets"

    init() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode([Preset].self, from: data) else { return }
        presets = saved
    }

    func save(name: String, document: IconDocument) {
        presets.append(Preset(name: name, document: document))
        persist()
    }

    func remove(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
