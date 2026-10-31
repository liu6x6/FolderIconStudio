import XCTest
@testable import FolderIconStudio

final class FolderValidationTests: XCTestCase {
    private let fileManager = FileManager.default
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("FolderIconStudioTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try fileManager.removeItem(at: temporaryDirectory)
    }

    func testAcceptsWritableOrdinaryFolder() async throws {
        let folderURL = temporaryDirectory!
        try await MainActor.run {
            try FinderIconService().validate(folderURL: folderURL)
        }
    }

    func testRejectsApplicationBundle() async throws {
        let applicationURL = temporaryDirectory.appendingPathComponent("Example.app", isDirectory: true)
        try fileManager.createDirectory(at: applicationURL, withIntermediateDirectories: true)

        do {
            try await MainActor.run {
                try FinderIconService().validate(folderURL: applicationURL)
            }
            XCTFail("Application bundles must be rejected.")
        } catch {
            XCTAssertEqual(error.localizedDescription, "“Example.app”是应用程序或系统包目录，不能修改其图标。")
        }
    }

    func testRejectsRegularFile() async throws {
        let fileURL = temporaryDirectory.appendingPathComponent("icon.txt")
        try Data().write(to: fileURL)

        do {
            try await MainActor.run {
                try FinderIconService().validate(folderURL: fileURL)
            }
            XCTFail("Files must be rejected.")
        } catch {
            XCTAssertTrue(error is FolderIconError)
        }
    }

    func testRejectsFolderWithoutWritePermission() async throws {
        let protectedFolder = temporaryDirectory.appendingPathComponent("ReadOnly", isDirectory: true)
        try fileManager.createDirectory(at: protectedFolder, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: protectedFolder.path)
        defer {
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: protectedFolder.path)
        }

        do {
            try await MainActor.run {
                try FinderIconService().validate(folderURL: protectedFolder)
            }
            XCTFail("Read-only folders must be rejected.")
        } catch {
            XCTAssertEqual(error.localizedDescription, "没有“ReadOnly”的修改权限。请选择你有写入权限的文件夹。")
        }
    }

    func testRecognizesICNSFileExtensionCaseInsensitively() {
        XCTAssertTrue(FinderIconService.isICNSFile(URL(fileURLWithPath: "/tmp/folder.ICNS")))
        XCTAssertFalse(FinderIconService.isICNSFile(URL(fileURLWithPath: "/tmp/folder.png")))
        XCTAssertFalse(FinderIconService.isICNSFile(URL(string: "https://example.com/folder.icns")!))
    }
}
