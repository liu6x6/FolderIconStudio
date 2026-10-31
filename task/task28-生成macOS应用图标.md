# 任务 28：生成 macOS 应用图标

## 目标

从品牌 SVG 生成完整的 macOS `AppIcon.appiconset`，并配置为应用图标。

## 实施步骤

1. 将 SVG 渲染为 App Icon 所需尺寸。
2. 创建标准 `AppIcon.appiconset` 与 `Contents.json`。
3. 在 XcodeGen 配置中指定 App Icon。
4. 构建并验证应用包中的图标资源。

## 验收标准

- Xcode 能识别 `AppIcon` 资源目录。
- 构建的 App 使用新的品牌图标。
