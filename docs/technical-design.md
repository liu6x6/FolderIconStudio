# Folder Icon Studio 技术设计文档

## 1. 技术决策

| 领域 | 方案 | 原因 |
| --- | --- | --- |
| 平台 | macOS 14+ | 可采用 SwiftData 与现代 SwiftUI API，降低兼容层复杂度。 |
| 语言 | Swift 5.10+ | 原生 Finder、图像和沙盒 API 支持完善。 |
| UI | SwiftUI 为主，AppKit 补充 | 快速构建三栏界面，同时保留原生文件操作能力。 |
| 渲染 | Core Graphics + Core Image | 输出可控的高分辨率位图，适合合成与导出。 |
| 系统集成 | AppKit `NSWorkspace`、`NSOpenPanel` | 设置目录图标、选择目录、打开 Finder 和 Dock 操作。 |
| 持久化 | SwiftData + Application Support 文件 | 保存可查询的模板元数据及图片资源。 |
| 并发 | Swift Concurrency | 使用 `async`/`await` 防止图像渲染和文件写入阻塞 UI。 |

## 2. 系统架构

```text
SwiftUI Views
    │
    ├── EditorViewModel (@MainActor)
    │       ├── IconDocument
    │       ├── UndoManager
    │       └── EditorCommand handlers
    │
    ├── IconRenderer (actor)
    ├── FinderIconService
    ├── BookmarkAccessService
    ├── IconExportService
    ├── PresetRepository
    └── AssetStore
            │
            ├── SwiftData
            └── Application Support/FolderIconStudio
```

视图层不得直接执行文件 I/O 或修改 Finder 图标。所有可失败的系统调用由 Service 返回带上下文的 `Error`，由 ViewModel 映射为可展示的错误状态。

## 3. 模块职责

| 模块 | 职责 |
| --- | --- |
| `App` | 应用生命周期、命令菜单、依赖注入、URL Scheme 入口。 |
| `Editor` | 三栏 UI、选中状态、快捷键、撤销/重做及编辑命令。 |
| `Domain` | `IconDocument`、`FolderStyle`、`IconLayer`、`Preset` 等值类型。 |
| `Rendering` | 将文档渲染为指定像素尺寸的 `CGImage` 或 `NSImage`。 |
| `FinderIntegration` | 应用、清除 Finder 自定义图标；打开目录；请求 Dock 添加。 |
| `Export` | PNG 写入及多尺寸 `.icns` 生成。 |
| `Persistence` | SwiftData 模板记录、书签与资源文件的持久化。 |
| `Security` | security-scoped bookmark 创建、恢复、访问生命周期管理。 |

## 4. 数据模型

编辑状态使用 `Codable` 值类型，便于模板保存、URL 自动化和测试。

```swift
struct IconDocument: Codable, Equatable, Sendable {
    var canvasSize: Int
    var folderStyle: FolderStyle
    var layers: [IconLayer]
}

struct FolderStyle: Codable, Equatable, Sendable {
    var fill: FillStyle
    var opacity: Double
    var shadow: ShadowStyle?
}

enum IconLayer: Codable, Equatable, Sendable {
    case symbol(SymbolLayer)
    case emoji(EmojiLayer)
    case text(TextLayer)
    case image(ImageLayer)
}

struct LayerTransform: Codable, Equatable, Sendable {
    var centerX: Double
    var centerY: Double
    var scale: Double
    var rotationDegrees: Double
    var opacity: Double
}
```

坐标应采用归一化画布空间（`0...1`），渲染时再换算到像素空间，以保证 128 px 预览和 1024 px 导出一致。图片图层只保存 Asset ID，二进制文件放在 Application Support，避免将大图片写入数据库。

## 5. 图标渲染与导出

### 5.1 渲染流程

1. 接收不可变的 `IconDocument` 快照和目标像素尺寸。
2. 创建 sRGB、带 alpha 的 `CGContext`。
3. 绘制文件夹基底：使用应用自带矢量路径或高分辨率基础资源，应用填充、渐变、阴影和透明度。
4. 按数组顺序绘制图层，依次应用 transform、裁剪与不透明度。
5. 生成 `CGImage`，返回调用方用于预览、应用或导出。

渲染器应作为 `actor`，并缓存以 `(documentHash, pixelSize, appearance)` 为键的结果。用户连续拖动时使用短暂防抖；释放操作后立即渲染最终图像。

### 5.2 尺寸与格式

- Finder 应用与 `.icns` 需要生成至少 16、32、64、128、256、512、1024 px 图像。
- PNG 导出使用 1024 px、sRGB、RGBA。
- `.icns` 导出优先通过临时 `iconset` 目录和系统 `iconutil -c icns` 生成；执行必须使用 `Process` 的参数数组，禁止拼接 shell 命令。
- 临时目录应在导出成功或失败后清理；清理失败需记录诊断日志，不应覆盖原始导出错误。

## 6. Finder 与 Dock 集成

### 6.1 设置与清除目录图标

使用 `NSWorkspace`：

```swift
try NSWorkspace.shared.setIcon(icon, forFile: folderURL.path, options: [])
```

清除时传入 `nil`。操作前必须验证：

- URL 是本地文件系统上的目录，且不是根目录。
- 应用当前持有该 URL 的访问权限。
- 目录可写；失败后把系统错误包装为包括路径、操作和底层错误的应用错误。

Finder 通常会自行刷新。若界面未更新，应用只可建议用户在 Finder 中重新打开目录，不能伪造成功状态。

### 6.2 Dock 与 URL Scheme

- “添加到 Dock”使用 `NSWorkspace.shared.requestUserAttention` 之外的公开 Dock 集成方式；若系统没有可靠公开 API，则改为在 Finder 中打开目录并明确告知用户手动拖入 Dock，不能依赖私有 API。
- 注册 `foldericonstudio` URL Scheme；仅接受 `foldericonstudio:///绝对路径`。
- URL 参数必须转为 file URL、规范化路径、验证目录存在，并沿用正常的权限获取流程。URL Scheme 不得绕过沙盒授权。

## 7. 沙盒、权限与隐私

Mac App Store 版本启用 App Sandbox，使用用户通过 `NSOpenPanel` 或拖放明确选择的目录。

1. 从选择结果创建 security-scoped bookmark。
2. 保存书签数据和显示名称，不保存无必要的用户目录内容。
3. 每次后台读取、应用或导出前解析书签，并使用 `startAccessingSecurityScopedResource()`。
4. 无论成功、失败或取消，都在 `defer` 中调用 `stopAccessingSecurityScopedResource()`。
5. 书签过期或无效时，明确提示用户重新选择对应目录。

所有图像编辑在本机完成。除非未来用户主动启用同步功能，应用不发起网络请求，也不上传路径、图标或模板。

## 8. 错误模型

```swift
enum FolderIconError: LocalizedError {
    case invalidFolder(URL)
    case accessDenied(URL, underlying: Error?)
    case bookmarkStale(URL)
    case renderFailed(underlying: Error)
    case finderUpdateFailed(URL, underlying: Error)
    case exportFailed(URL, underlying: Error)
}
```

禁止吞掉系统错误或返回成功形态的默认值。`ViewModel` 应保留底层错误用于诊断，并提供本地化、可行动的用户提示。

## 9. 性能与可靠性要求

| 指标 | 目标 |
| --- | --- |
| 常见单图层预览更新 | 100 ms 内完成 |
| 1024 px 单图标渲染 | 500 ms 内完成 |
| 批量任务 | 后台串行文件写入；UI 显示进度且保持可响应 |
| 图层上限 | MVP 限制 20 个，超出时阻止添加并显示原因 |
| 图片输入 | 读取前检查像素尺寸和解码内存；拒绝损坏文件 |

批量操作不得并发写入同一目录。每项独立捕获并呈现错误，取消操作只停止尚未开始的项目。

## 10. 测试策略

| 层级 | 覆盖内容 |
| --- | --- |
| 单元测试 | 文档编解码、图层变换、渲染参数、错误映射、书签状态。 |
| 快照测试 | 颜色、Symbol、Emoji、文字、图片及叠加图层的多尺寸输出。 |
| 集成测试 | 临时目录的设置图标、清除图标、PNG 导出与 `.icns` 可读性。 |
| UI 测试 | 空状态、目录选择、添加图层、撤销、导出与错误提示。 |
| 手工验证 | Finder 刷新表现、沙盒构建、深浅外观、VoiceOver 和键盘导航。 |

为 Finder 集成定义 `WorkspaceIconSetting` 协议，并在单元测试中注入 fake；仅集成测试使用真实 `NSWorkspace` 和临时目录。

## 11. 实施顺序

1. 建立 SwiftUI App、三栏骨架、领域模型与无文件操作的编辑器。
2. 实现 Core Graphics 渲染器、预览与 PNG 导出，并为渲染增加快照测试。
3. 接入目录选择、沙盒书签和 `NSWorkspace` 图标设置/清除。
4. 实现预设持久化、图片资源管理、撤销/重做与错误呈现。
5. 增加 `.icns` 导出、URL Scheme、批处理和可访问性验证。

每一步完成后均应保留无权限、损坏图片、导出失败和 Finder 写入失败的可观察错误路径。
