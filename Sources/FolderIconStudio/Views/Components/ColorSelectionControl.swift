import SwiftUI

struct ColorSelectionControl: View {
    let title: String
    @Binding var color: ColorValue
    let presets: [FolderColorPreset]
    let onScreenSample: (() -> Void)?
    let showsHexValue: Bool

    init(
        title: String,
        color: Binding<ColorValue>,
        presets: [FolderColorPreset] = [],
        onScreenSample: (() -> Void)? = nil,
        showsHexValue: Bool = false
    ) {
        self.title = title
        _color = color
        self.presets = presets
        self.onScreenSample = onScreenSample
        self.showsHexValue = showsHexValue
    }

    var body: some View {
        ColorPicker(title, selection: Binding(
            get: { color.color },
            set: { color = ColorValue($0) }
        ))

        if !presets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("预设颜色")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 30), spacing: 8)], spacing: 8) {
                    ForEach(presets) { preset in
                        Button {
                            color = preset.color
                        } label: {
                            Circle()
                                .fill(preset.color.color)
                                .frame(width: 26, height: 26)
                                .overlay {
                                    Circle().stroke(
                                        color == preset.color ? Color.primary : .clear,
                                        lineWidth: 2
                                    )
                                }
                        }
                        .buttonStyle(.plain)
                        .help("\(preset.name) \(preset.color.hexRGB)")
                        .accessibilityLabel("\(preset.name)，\(preset.color.hexRGB)")
                    }
                }
            }
        }

        if let onScreenSample {
            Button(action: onScreenSample) {
                Image(systemName: "eyedropper")
            }
            .buttonStyle(.bordered)
            .help("从屏幕取色")
            .accessibilityLabel("从屏幕取色")
        }

        if showsHexValue {
            Text("当前颜色：\(color.hexRGB)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
