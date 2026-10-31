import AppKit
import OSLog
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var document = IconDocument() {
        didSet {
            registerDocumentChange(from: oldValue)
        }
    }
    @Published var folderURL: URL?
    @Published var selectedLayerID: UUID?
    @Published var message: String?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private let finderService = FinderIconService()
    private let exportService = IconExportService()
    private let colorSampler = NSColorSampler()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.foldericonstudio.app", category: "ColorSelection")
    private let undoManager = UndoManager()
    private var isRestoringDocument = false
    let availableFontFamilies: [String]

    init() {
        availableFontFamilies = NSFontManager.shared.availableFontFamilies.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var selectedLayerIndex: Int? {
        guard let selectedLayerID else { return nil }
        return document.layers.firstIndex { $0.id == selectedLayerID }
    }

    var selectedSymbolLayer: SymbolLayer? {
        guard let selectedLayerIndex,
              case .symbol(let symbol) = document.layers[selectedLayerIndex] else {
            return nil
        }
        return symbol
    }

    func undo() {
        guard undoManager.canUndo else { return }
        undoManager.undo()
        refreshUndoState()
    }

    func redo() {
        guard undoManager.canRedo else { return }
        undoManager.redo()
        refreshUndoState()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url {
            selectFolder(url)
        }
    }

    func exportICNS() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "icns") ?? .data]
        panel.nameFieldStringValue = "FolderIcon.icns"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try exportService.exportICNS(document: document, to: url)
            message = "已导出 ICNS 到“\(url.lastPathComponent)”。"
        } catch {
            message = error.localizedDescription
        }
    }

    func acceptDroppedURLs(_ urls: [URL]) -> Bool {
        guard let url = urls.first else { return false }
        selectFolder(url)
        return true
    }

    @discardableResult
    func addSymbol(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              NSImage(systemSymbolName: trimmedName, accessibilityDescription: nil) != nil else {
            message = "“\(trimmedName.isEmpty ? name : trimmedName)”不是当前 macOS 可用的 SF Symbol 名称。"
            return false
        }
        let layer = IconLayer.symbol(SymbolLayer(symbolName: trimmedName))
        document.layers.append(layer)
        selectedLayerID = layer.id
        return true
    }

    func addEmoji(_ emoji: String) {
        let layer = IconLayer.emoji(TextLayer(text: emoji))
        document.layers.append(layer)
        selectedLayerID = layer.id
    }

    func addText() {
        let layer = IconLayer.text(TextLayer(text: "TEXT"))
        document.layers.append(layer)
        selectedLayerID = layer.id
    }

    func importImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        panel.allowsMultipleSelection = false
        panel.prompt = "添加图片"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let layer = IconLayer.image(ImageLayer(filePath: url.path))
        document.layers.append(layer)
        selectedLayerID = layer.id
    }

    func deleteSelectedLayer() {
        guard let selectedLayerIndex else { return }
        document.layers.remove(at: selectedLayerIndex)
        selectedLayerID = nil
    }

    func moveSelectedLayer(by offset: Int) {
        guard let index = selectedLayerIndex else { return }
        let destination = index + offset
        guard document.layers.indices.contains(destination) else { return }
        let layer = document.layers.remove(at: index)
        document.layers.insert(layer, at: destination)
    }

    func applyToFinder() {
        guard let folderURL else {
            message = "请先选择要修改的文件夹。"
            return
        }
        do {
            try finderService.apply(document: document, to: folderURL)
            message = "已将自定义图标应用到“\(folderURL.lastPathComponent)”。"
        } catch {
            message = error.localizedDescription
        }
    }

    func applyICNSFile() {
        guard let folderURL else {
            message = "请先选择要修改的文件夹。"
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "icns") ?? .data]
        panel.allowsMultipleSelection = false
        panel.prompt = "应用图标"
        guard panel.runModal() == .OK, let iconURL = panel.url else { return }

        do {
            try finderService.applyICNS(at: iconURL, to: folderURL)
            message = "已将“\(iconURL.lastPathComponent)”应用到“\(folderURL.lastPathComponent)”。"
        } catch {
            message = error.localizedDescription
        }
    }

    func restoreDefaultIcon() {
        guard let folderURL else {
            message = "请先选择要恢复的文件夹。"
            return
        }
        do {
            try finderService.clearIcon(from: folderURL)
            message = "已恢复“\(folderURL.lastPathComponent)”的默认图标。"
        } catch {
            message = error.localizedDescription
        }
    }

    func exportPNG() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "FolderIcon.png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try exportService.exportPNG(document: document, to: url)
            message = "已导出 PNG 到“\(url.lastPathComponent)”。"
        } catch {
            message = error.localizedDescription
        }
    }

    func setFolderColor(_ color: ColorValue, source: String) {
        document.folderStyle.color = color
        logger.info("Folder color selected from \(source, privacy: .public): \(color.hexRGB, privacy: .public)")
    }

    func sampleScreenColor() {
        sampleScreenColor { [weak self] color in
            self?.setFolderColor(color, source: "screen sampler")
        }
    }

    func sampleScreenColorForSelectedText() {
        sampleScreenColor { [weak self] color in
            self?.updateSelectedTextColor(color)
        }
    }

    func sampleScreenColorForSelectedSymbol() {
        sampleScreenColor { [weak self] color in
            self?.updateSelectedSymbolColor(color)
        }
    }

    private func sampleScreenColor(applying update: @escaping @MainActor (ColorValue) -> Void) {
        colorSampler.show { [weak self] color in
            guard let color else { return }
            Task { @MainActor in
                guard self != nil else { return }
                update(ColorValue(color))
            }
        }
    }

    func updateSelectedTransform(_ update: (inout LayerTransform) -> Void) {
        guard let index = selectedLayerIndex else { return }
        var layer = document.layers[index]
        var transform = layer.transform
        update(&transform)
        layer.transform = transform
        document.layers[index] = layer
    }

    func updateSelectedText(_ text: String) {
        guard let index = selectedLayerIndex else { return }
        switch document.layers[index] {
        case .emoji(var layer):
            layer.text = text
            document.layers[index] = .emoji(layer)
        case .text(var layer):
            layer.text = text
            document.layers[index] = .text(layer)
        default:
            break
        }
    }

    func updateSelectedTextFontFamily(_ fontFamily: String) {
        guard let index = selectedLayerIndex,
              case .text(var layer) = document.layers[index] else { return }
        layer.fontFamily = fontFamily.isEmpty ? nil : fontFamily
        document.layers[index] = .text(layer)
    }

    func updateSelectedTextFontWeight(_ fontWeight: TextFontWeight) {
        guard let index = selectedLayerIndex,
              case .text(var layer) = document.layers[index] else { return }
        layer.fontWeight = fontWeight
        document.layers[index] = .text(layer)
    }

    func updateSelectedTextItalic(_ isItalic: Bool) {
        guard let index = selectedLayerIndex,
              case .text(var layer) = document.layers[index] else { return }
        layer.isItalic = isItalic
        document.layers[index] = .text(layer)
    }

    func updateSelectedTextColor(_ color: ColorValue) {
        guard let index = selectedLayerIndex,
              case .text(var layer) = document.layers[index] else { return }
        layer.color = color
        document.layers[index] = .text(layer)
    }

    func updateSelectedSymbolName(_ name: String) {
        guard let index = selectedLayerIndex,
              case .symbol(var layer) = document.layers[index] else { return }
        layer.symbolName = name
        document.layers[index] = .symbol(layer)
    }

    func updateSelectedSymbolRenderingMode(_ renderingMode: SymbolRenderingMode) {
        guard let index = selectedLayerIndex,
              case .symbol(var layer) = document.layers[index] else { return }
        layer.renderingMode = renderingMode
        document.layers[index] = .symbol(layer)
    }

    func updateSelectedSymbolColor(_ color: ColorValue) {
        guard let index = selectedLayerIndex,
              case .symbol(var layer) = document.layers[index] else { return }
        layer.color = color
        document.layers[index] = .symbol(layer)
    }

    private func selectFolder(_ url: URL) {
        do {
            try finderService.validate(folderURL: url)
            folderURL = url
        } catch {
            message = error.localizedDescription
        }
    }

    private func registerDocumentChange(from previousDocument: IconDocument) {
        guard !isRestoringDocument, document != previousDocument else { return }
        undoManager.registerUndo(withTarget: self) { target in
            target.restoreDocument(previousDocument)
        }
        undoManager.setActionName("编辑图标")
        refreshUndoState()
    }

    private func restoreDocument(_ restoredDocument: IconDocument) {
        let currentDocument = document
        isRestoringDocument = true
        document = restoredDocument
        isRestoringDocument = false
        undoManager.registerUndo(withTarget: self) { target in
            target.restoreDocument(currentDocument)
        }
        refreshUndoState()
    }

    private func refreshUndoState() {
        canUndo = undoManager.canUndo
        canRedo = undoManager.canRedo
    }
}
