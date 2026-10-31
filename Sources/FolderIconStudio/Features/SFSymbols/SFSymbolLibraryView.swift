import SwiftUI

struct SFSymbolLibraryView: View {
    @ObservedObject var editor: EditorViewModel
    @State private var symbolName = ""
    @State private var symbolQuery = ""
    @State private var selectedCategoryID = SFSymbolCatalog.defaultCategoryID
    @State private var displayLimit = 200

    private let catalog = SFSymbolCatalog.shared

    private var filteredSymbols: [String] {
        catalog.symbols(in: selectedCategoryID, matching: symbolQuery)
    }

    private var displayedSymbols: ArraySlice<String> {
        filteredSymbols.prefix(displayLimit)
    }

    var body: some View {
        TextField("SF Symbol 名称", text: $symbolName)
            .textFieldStyle(.roundedBorder)
            .onSubmit(addEnteredSymbol)

        Button("添加 Symbol", action: addEnteredSymbol)
            .disabled(symbolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Picker("分类", selection: $selectedCategoryID) {
            ForEach(catalog.categories) { category in
                Text("\(category.displayName) (\(catalog.symbolCount(in: category.id)))")
                    .tag(category.id)
            }
        }
        .onChange(of: selectedCategoryID) { _, _ in
            displayLimit = 200
        }

        TextField("搜索全部 Symbol", text: $symbolQuery)
            .textFieldStyle(.roundedBorder)
            .onChange(of: symbolQuery) { _, _ in
                displayLimit = 200
            }

        Text("显示 \(displayedSymbols.count) / \(filteredSymbols.count) 个 Symbol")
            .font(.caption)
            .foregroundStyle(.secondary)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 34))], spacing: 8) {
            ForEach(displayedSymbols, id: \.self) { symbol in
                Button { _ = editor.addSymbol(symbol) } label: {
                    Image(systemName: symbol).frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .help(symbol)
                .accessibilityLabel(symbol)
            }
        }
        if displayLimit < filteredSymbols.count {
            Button("显示更多 Symbol") {
                displayLimit += 200
            }
        }

    }

    private func addEnteredSymbol() {
        if editor.addSymbol(symbolName) {
            symbolName = ""
        }
    }

    struct SymbolPropertiesSection: View {
        @ObservedObject var editor: EditorViewModel

        var body: some View {
            InspectorSection("Symbol 属性") {
                TextField("符号名称", text: Binding(
                    get: { editor.selectedSymbolLayer?.symbolName ?? "" },
                    set: { editor.updateSelectedSymbolName($0) }
                ))
                Picker("渲染模式", selection: Binding(
                    get: { editor.selectedSymbolLayer?.renderingMode ?? .monochrome },
                    set: { editor.updateSelectedSymbolRenderingMode($0) }
                )) {
                    ForEach(SymbolRenderingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                ColorPicker("Symbol 颜色", selection: Binding(
                    get: { editor.selectedSymbolLayer?.color.color ?? .white },
                    set: { editor.updateSelectedSymbolColor(ColorValue($0)) }
                ))
                if editor.selectedSymbolLayer?.renderingMode == .multicolor {
                    Text("多彩模式会从所选颜色生成亮色与暗色 palette。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
