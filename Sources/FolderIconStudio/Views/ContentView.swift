import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var editor = EditorViewModel()
    @StateObject private var presetStore = PresetStore()
    @State private var showingSavePreset = false
    @State private var presetName = ""
    @State private var confirmingRestore = false
    @State private var showingExportOptions = false
    @State private var isInspectorPresented = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ResourceSidebar(editor: editor, presetStore: presetStore)
                .navigationSplitViewColumnWidth(min: 380, ideal: 400, max: 440)
        } detail: {
            HStack(spacing: 0) {
                EditorCanvas(editor: editor)
                    .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)
                if isInspectorPresented {
                    Divider()
                    InspectorView(editor: editor)
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 360, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1_120, minHeight: 620)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: editor.chooseFolder) {
                    Label("选择文件夹", systemImage: "folder.badge.plus")
                }
                Menu {
                    Button("导出 PNG", action: editor.exportPNG)
                    Button("导出多尺寸 PNG") { showingExportOptions = true }
                    Button("导出 ICNS", action: editor.exportICNS)
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                Button(action: { showingSavePreset = true }) {
                    Label("保存模板", systemImage: "bookmark")
                }
                Button(action: editor.undo) {
                    Label("撤销", systemImage: "arrow.uturn.backward")
                }
                .disabled(!editor.canUndo)
                Button(action: editor.redo) {
                    Label("重做", systemImage: "arrow.uturn.forward")
                }
                .disabled(!editor.canRedo)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button("应用当前设计", action: editor.applyToFinder)
                    Button("应用 ICNS 文件", action: editor.applyICNSFile)
                } label: {
                    Label("应用到 Finder", systemImage: "checkmark.circle.fill")
                }
                .disabled(editor.folderURL == nil)
                Button {
                    isInspectorPresented.toggle()
                } label: {
                    Label(
                        isInspectorPresented ? "隐藏属性" : "显示属性",
                        systemImage: "sidebar.right"
                    )
                }
            }
            ToolbarItem(placement: .automatic) {
                Button(role: .destructive, action: { confirmingRestore = true }) {
                    Label("恢复默认", systemImage: "arrow.counterclockwise")
                }
                .disabled(editor.folderURL == nil)
            }
        }
        .alert("Folder Icon Studio", isPresented: Binding(
            get: { editor.message != nil },
            set: { if !$0 { editor.message = nil } }
        )) {
            Button("好", role: .cancel) { editor.message = nil }
        } message: {
            Text(editor.message ?? "")
        }
        .confirmationDialog("恢复系统默认文件夹图标？", isPresented: $confirmingRestore, titleVisibility: .visible) {
            Button("恢复默认图标", role: .destructive, action: editor.restoreDefaultIcon)
        } message: {
            Text("这会清除目标文件夹当前的自定义 Finder 图标。")
        }
        .alert("保存模板", isPresented: $showingSavePreset) {
            TextField("模板名称", text: $presetName)
            Button("取消", role: .cancel) { presetName = "" }
            Button("保存") {
                let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
                presetStore.save(name: name.isEmpty ? "未命名模板" : name, document: editor.document)
                presetName = ""
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView(editor: editor)
            }
        }
    }

    private struct ExportOptionsView: View {
        @Environment(\.dismiss) private var dismiss
        @ObservedObject var editor: EditorViewModel
        @State private var sizes: Set<Int> = [128, 256, 512, 1024]
        @State private var transparentBackground = true

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("多尺寸 PNG 导出").font(.title2.weight(.semibold))
                PreviewImage(document: editor.document, size: 128)
                    .frame(maxWidth: .infinity)
                Text("尺寸")
                ForEach([128, 256, 512, 1024], id: \.self) { size in
                    Toggle("\(size) x \(size) px", isOn: Binding(
                        get: { sizes.contains(size) },
                        set: { selected in
                            if selected {
                                sizes.insert(size)
                            } else {
                                sizes.remove(size)
                            }
                        }
                    ))
                }
                Toggle("透明背景", isOn: $transparentBackground)
                HStack {
                    Spacer()
                    Button("取消") { dismiss() }
                    Button("导出") {
                        editor.exportPNGBatch(
                            pixelSizes: sizes.sorted(),
                            transparentBackground: transparentBackground
                        )
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sizes.isEmpty)
                }
            }
            .padding(24)
            .frame(width: 360)
        }
    }
}

private struct ResourceSidebar: View {
    @ObservedObject var editor: EditorViewModel
    @ObservedObject var presetStore: PresetStore
    private let emojis = ["📁", "💼", "⭐️", "🎨", "📷", "🚀"]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SidebarSection("当前文件夹", systemImage: "folder.fill") {
                if let folderURL = editor.folderURL {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(folderURL.lastPathComponent, systemImage: "folder.fill")
                            .font(.subheadline.weight(.semibold))
                        Text(folderURL.path)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .help(folderURL.path)
                } else {
                    ContentUnavailableView("尚未选择文件夹", systemImage: "folder.badge.question")
                }
                }

                SidebarSection("符号图标", systemImage: "sparkles") {
                    ScrollView(.vertical, showsIndicators: false) {
                        SFSymbolLibraryView(editor: editor)
                    }
                    .frame(height: 320)
                }

                SidebarSection("Emoji", systemImage: "face.smiling") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                        spacing: 8
                    ) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button(emoji) { editor.addEmoji(emoji) }
                            .buttonStyle(.borderless)
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                }
                }

                SidebarSection("添加图层", systemImage: "plus.circle.fill") {
                    Button("添加文字", systemImage: "textformat") { editor.addText() }
                        .buttonStyle(.borderedProminent)
                    Button("导入图片", systemImage: "photo") { editor.importImage() }
                        .buttonStyle(.bordered)
                }

                SidebarSection("预设模板", systemImage: "bookmark.fill") {
                    if presetStore.presets.isEmpty {
                        Text("保存设计后会显示在这里。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.fixed(50), spacing: 8), count: 5),
                                spacing: 8
                            ) {
                                ForEach(presetStore.presets) { preset in
                                    PresetTile(preset: preset) {
                                        editor.document = preset.document
                                        editor.selectedLayerID = nil
                                    } onDelete: {
                                        presetStore.remove(preset)
                                    }
                                }
                            }
                        }
                        .frame(height: 108)
                    }
                }
            }
        }
        .contentMargins(.all, 12, for: .scrollContent)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SidebarSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PresetTile: View {
    let preset: Preset
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            PreviewImage(document: preset.document, size: 44)
                .frame(width: 50, height: 50)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.secondary.opacity(0.25), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(preset.name)
        .accessibilityLabel("应用模板 \(preset.name)")
        .contextMenu {
            Button("删除模板", role: .destructive, action: onDelete)
        }
    }
}

private struct EditorCanvas: View {
    @ObservedObject var editor: EditorViewModel
    @State private var previewSize = 512.0
    @State private var isDropTarget = false

    var body: some View {
        VStack(spacing: 18) {
            if editor.folderURL == nil {
                VStack(spacing: 8) {
                    Button(action: editor.chooseFolder) {
                        Image(systemName: "folder.badge.plus")
                            .font(.largeTitle)
                    }
                    .buttonStyle(.plain)
                    .help("选择文件夹")
                    .accessibilityLabel("选择文件夹")
                    Text("拖入文件夹开始设计")
                        .font(.headline)
                }
            }

            PreviewImage(document: editor.document, size: previewSize)
                .overlay {
                    if isDropTarget {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.tint, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    }
                }
                .padding(28)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
                .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in
                    guard let provider = providers.first else { return false }
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        guard let data = item as? Data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                        Task { @MainActor in
                            _ = editor.acceptDroppedURLs([url])
                        }
                    }
                    return true
                }

            Picker("预览尺寸", selection: $previewSize) {
                Text("128 px").tag(128.0)
                Text("256 px").tag(256.0)
                Text("512 px").tag(512.0)
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
        }
        .padding()
    }
}

private struct PreviewImage: View {
    let document: IconDocument
    let size: Double

    var body: some View {
        Group {
            if let image = try? IconRenderer.shared.render(document: document, pixelSize: size) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: min(size, 440), height: min(size, 440))
        .accessibilityLabel("文件夹图标预览")
    }
}

private struct InspectorView: View {
    @ObservedObject var editor: EditorViewModel
    @State private var selectedTab: InspectorTab = .folderStyle

    var body: some View {
        VStack(spacing: 0) {
            Picker("属性标签", selection: $selectedTab) {
                ForEach(InspectorTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear
                            .frame(height: 0)
                            .id(InspectorScrollAnchor.top)
                    if selectedTab == .folderStyle {
            InspectorSection("文件夹样式") {
                Picker("底图", selection: $editor.document.folderStyle.baseIcon) {
                    ForEach(FolderBaseIcon.allCases) { baseIcon in
                        Text(baseIcon.displayName).tag(baseIcon)
                    }
                }
                ColorSelectionControl(
                    title: "颜色",
                    color: Binding(
                        get: { editor.document.folderStyle.color },
                        set: { editor.setFolderColor($0, source: "color control") }
                    ),
                    presets: FolderColorPreset.all,
                    onScreenSample: { editor.sampleScreenColor() },
                    showsHexValue: true
                )
                Slider(value: $editor.document.folderStyle.opacity, in: 0...1) {
                    Text("不透明度")
                }
            }
                    }

                    if selectedTab == .layers {
            InspectorSection("图层") {
                ForEach(editor.document.layers.indices, id: \.self) { index in
                    Button {
                        editor.selectedLayerID = editor.document.layers[index].id
                    } label: {
                        HStack {
                            Image(systemName: editor.document.layers[index].iconName)
                                .foregroundStyle(.secondary)
                            Text(editor.document.layers[index].title).lineLimit(1)
                            Spacer()
                            if !editor.document.layers[index].transform.isVisible {
                                Image(systemName: "eye.slash")
                                    .foregroundStyle(.secondary)
                            }
                            if editor.document.layers[index].transform.isLocked {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(
                            editor.selectedLayerID == editor.document.layers[index].id
                                ? Color.accentColor.opacity(0.18)
                                : .clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let index = editor.selectedLayerIndex {
                LayerInspector(editor: editor, layer: editor.document.layers[index])
            }
                    }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentMargins(.all, 0, for: .scrollContent)
                .onChange(of: editor.folderURL) { _, _ in
                    proxy.scrollTo(InspectorScrollAnchor.top, anchor: .top)
                }
                .onChange(of: selectedTab) { _, _ in
                    proxy.scrollTo(InspectorScrollAnchor.top, anchor: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private enum InspectorTab: String, CaseIterable, Identifiable {
    case layers
    case folderStyle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .layers: "图层"
        case .folderStyle: "文件夹样式"
        }
    }
}

private enum InspectorScrollAnchor {
    static let top = "inspector-scroll-top"
}

private struct LayerInspector: View {
    @ObservedObject var editor: EditorViewModel
    let layer: IconLayer
    @State private var fontSearch = ""

    var body: some View {
        Group {
            LayerActionsSection(editor: editor)
            if case .symbol = layer {
                SFSymbolLibraryView.SymbolPropertiesSection(editor: editor)
            }
            InspectorSection("图层属性") {
            if case .emoji(let text) = layer {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Emoji")
                    EmojiTextField(text: Binding(
                        get: { text.text },
                        set: { editor.updateSelectedText($0) }
                    ))
                    .frame(height: 22)
                    Text("点击输入框可打开系统 Emoji 与符号面板。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if case .text(let text) = layer {
                TextField("内容", text: Binding(get: { text.text }, set: { editor.updateSelectedText($0) }))
                TextField("搜索字体", text: $fontSearch, prompt: Text("输入字体名称"))
                Picker("字体", selection: Binding(
                    get: { text.fontFamily ?? "" },
                    set: { editor.updateSelectedTextFontFamily($0) }
                )) {
                    Text("系统默认").tag("")
                    ForEach(filteredFontFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }
                Picker("字重", selection: Binding(
                    get: { text.fontWeight },
                    set: { editor.updateSelectedTextFontWeight($0) }
                )) {
                    ForEach(TextFontWeight.allCases) { weight in
                        Text(weight.displayName).tag(weight)
                    }
                }
                Toggle("斜体", isOn: Binding(
                    get: { text.isItalic },
                    set: { editor.updateSelectedTextItalic($0) }
                ))
                ColorSelectionControl(
                    title: "文字颜色",
                    color: Binding(
                        get: { text.color },
                        set: { editor.updateSelectedTextColor($0) }
                    ),
                    presets: FolderColorPreset.all,
                    onScreenSample: { editor.sampleScreenColorForSelectedText() },
                    showsHexValue: true
                )
            }
            HStack {
                Text("大小")
                Slider(value: transformBinding(\.scale), in: 0.1...1)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("不透明度")
                    Spacer()
                    Text("\(Int(opacityPercentage.rounded()))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: opacityBinding, in: 0...100, step: 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("旋转")
                    Spacer()
                    Text("\(Int(rotationDegrees.rounded()))°")
                        .foregroundStyle(.secondary)
                }
                Slider(value: rotationBinding, in: 0...359, step: 1)
            }
            HStack {
                Text("水平位置")
                Slider(value: transformBinding(\.centerX), in: 0...1)
            }
            HStack {
                Text("垂直位置")
                Slider(value: transformBinding(\.centerY), in: 0...1)
            }
            }
        }
    }

    private func transformBinding(_ keyPath: WritableKeyPath<LayerTransform, Double>) -> Binding<Double> {
        Binding(
            get: { editor.selectedLayerIndex.map { editor.document.layers[$0].transform[keyPath: keyPath] } ?? 0 },
            set: { value in editor.updateSelectedTransform { $0[keyPath: keyPath] = value } }
        )
    }

    private var filteredFontFamilies: [String] {
        let query = fontSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return editor.availableFontFamilies }
        return editor.availableFontFamilies.filter {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    private var opacityPercentage: Double {
        (editor.selectedLayerIndex.map { editor.document.layers[$0].transform.opacity } ?? 0) * 100
    }

    private var rotationDegrees: Double {
        let rotation = editor.selectedLayerIndex.map { editor.document.layers[$0].transform.rotationDegrees } ?? 0
        return rotation.truncatingRemainder(dividingBy: 360) + (rotation < 0 ? 360 : 0)
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { opacityPercentage },
            set: { value in editor.updateSelectedTransform { $0.opacity = value / 100 } }
        )
    }

    private var rotationBinding: Binding<Double> {
        Binding(
            get: { rotationDegrees },
            set: { value in editor.updateSelectedTransform { $0.rotationDegrees = value } }
        )
    }
}

private struct LayerActionsSection: View {
    @ObservedObject var editor: EditorViewModel

    var body: some View {
        InspectorSection("图层操作") {
            HStack {
                Button(action: editor.duplicateSelectedLayer) {
                    Image(systemName: "plus.square.on.square")
                }
                .help("复制图层")
                Button(action: editor.toggleSelectedLayerVisibility) {
                    Image(systemName: editor.selectedLayerIndex.map { editor.document.layers[$0].transform.isVisible } == true ? "eye" : "eye.slash")
                }
                .help("显示或隐藏图层")
                Button(action: editor.toggleSelectedLayerLock) {
                    Image(systemName: editor.selectedLayerIndex.map { editor.document.layers[$0].transform.isLocked } == true ? "lock.fill" : "lock.open")
                }
                .help("锁定或解锁图层")
                Button {
                    editor.moveSelectedLayer(by: -1)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .help("下移一层")
                .accessibilityLabel("下移一层")
                Button {
                    editor.moveSelectedLayer(by: 1)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .help("上移一层")
                .accessibilityLabel("上移一层")
                Spacer()
                Button(role: .destructive, action: editor.deleteSelectedLayer) {
                    Image(systemName: "trash")
                }
                .help("删除图层")
                .accessibilityLabel("删除图层")
            }
        }
    }
}
