// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FolderIconStudio",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FolderIconStudio", targets: ["FolderIconStudio"])
    ],
    targets: [
        .executableTarget(
            name: "FolderIconStudio",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "FolderIconStudioTests", dependencies: ["FolderIconStudio"])
    ]
)
