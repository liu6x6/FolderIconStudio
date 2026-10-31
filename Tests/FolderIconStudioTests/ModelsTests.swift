import XCTest
import AppKit
@testable import FolderIconStudio

final class ModelsTests: XCTestCase {
    func testDocumentRoundTripsThroughJSON() throws {
        let document = IconDocument(
            folderStyle: FolderStyle(color: .purple, opacity: 0.8, baseIcon: .group),
            layers: [
                .symbol(SymbolLayer(symbolName: "star.fill")),
                .emoji(TextLayer(text: "🚀")),
                .text(TextLayer(text: "WORK"))
            ]
        )

        let data = try JSONEncoder().encode(document)
        XCTAssertEqual(try JSONDecoder().decode(IconDocument.self, from: data), document)
    }

    func testLayerTransformCanBeUpdated() {
        var layer = IconLayer.symbol(SymbolLayer(symbolName: "star.fill"))
        layer.transform.scale = 0.75
        layer.transform.rotationDegrees = 45

        XCTAssertEqual(layer.transform.scale, 0.75)
        XCTAssertEqual(layer.transform.rotationDegrees, 45)
    }

    func testFolderColorPresetsHaveExpectedCountAndHexValues() {
        XCTAssertEqual(FolderColorPreset.all.count, 18)
        XCTAssertEqual(FolderColorPreset.all[0].color.hexRGB, "#2980D9")
        XCTAssertEqual(ColorValue(red: -1, green: 1.5, blue: 0.5).hexRGB, "#00FF80")
    }

    func testSymbolLayerDecodesExistingTemplateAsMonochrome() throws {
        let symbol = SymbolLayer(symbolName: "star.fill", renderingMode: .multicolor)
        let encodedData = try JSONEncoder().encode(symbol)
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: encodedData) as? [String: Any])
        object.removeValue(forKey: "renderingMode")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        XCTAssertEqual(
            try JSONDecoder().decode(SymbolLayer.self, from: legacyData).renderingMode,
            .monochrome
        )
    }

    func testTextLayerPersistsTypographyAndDecodesExistingTemplate() throws {
        let textLayer = TextLayer(
            text: "Hello",
            color: .orange,
            fontFamily: "Helvetica",
            fontWeight: .heavy,
            isItalic: true
        )
        let encodedData = try JSONEncoder().encode(textLayer)
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: encodedData) as? [String: Any])
        object.removeValue(forKey: "fontFamily")
        object.removeValue(forKey: "fontWeight")
        object.removeValue(forKey: "isItalic")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let legacyLayer = try JSONDecoder().decode(TextLayer.self, from: legacyData)
        let decodedLayer = try JSONDecoder().decode(TextLayer.self, from: encodedData)
        XCTAssertNil(legacyLayer.fontFamily)
        XCTAssertEqual(legacyLayer.fontWeight, .bold)
        XCTAssertFalse(legacyLayer.isItalic)
        XCTAssertEqual(decodedLayer.fontFamily, "Helvetica")
        XCTAssertEqual(decodedLayer.fontWeight, .heavy)
        XCTAssertTrue(decodedLayer.isItalic)
        XCTAssertEqual(decodedLayer.color, .orange)
    }

    func testBundledSymbolCatalogContainsSystemSymbolSet() {
        let catalog = SFSymbolCatalog.shared

        XCTAssertEqual(catalog.symbols.count, 8_302)
        XCTAssertGreaterThan(catalog.categories.count, 20)
        XCTAssertTrue(catalog.symbols.contains("star.fill"))
    }

    @MainActor
    func testAllSystemFolderVariantsRender() throws {
        for baseIcon in FolderBaseIcon.allCases {
            let document = IconDocument(folderStyle: FolderStyle(baseIcon: baseIcon))
            let image = try IconRenderer.shared.render(document: document, pixelSize: 256)
            XCTAssertEqual(image.size, NSSize(width: 256, height: 256))
        }
    }

    @MainActor
    func testFolderColorChangesRenderedImage() throws {
        let blue = try IconRenderer.shared.render(
            document: IconDocument(folderStyle: FolderStyle(color: .blue)),
            pixelSize: 128
        )
        let red = try IconRenderer.shared.render(
            document: IconDocument(folderStyle: FolderStyle(color: ColorValue(red: 0.86, green: 0.30, blue: 0.28))),
            pixelSize: 128
        )

        XCTAssertNotEqual(blue.tiffRepresentation, red.tiffRepresentation)
    }

    @MainActor
    func testFolderColorDoesNotFillTransparentBackground() throws {
        let image = try IconRenderer.shared.render(
            document: IconDocument(folderStyle: FolderStyle(color: ColorValue(red: 0.86, green: 0.30, blue: 0.28))),
            pixelSize: 128
        )
        let bitmap = try XCTUnwrap(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let cornerColor = try XCTUnwrap(bitmap.colorAt(x: 0, y: 0))

        XCTAssertEqual(cornerColor.alphaComponent, 0, accuracy: 0.01)
    }

    @MainActor
    func testRendererCachesMatchingDocumentAndSize() throws {
        let renderer = IconRenderer.shared
        renderer.clearRenderedImageCache()
        let document = IconDocument(layers: [.symbol(SymbolLayer(symbolName: "star.fill"))])

        let first = try renderer.render(document: document, pixelSize: 128)
        let second = try renderer.render(document: document, pixelSize: 128)

        XCTAssertTrue(first === second)
    }

    @MainActor
    func testRendererInvalidatesCacheWhenDocumentChanges() throws {
        let renderer = IconRenderer.shared
        renderer.clearRenderedImageCache()
        let document = IconDocument(layers: [.symbol(SymbolLayer(symbolName: "star.fill"))])
        var changedDocument = document
        changedDocument.folderStyle.color = .orange

        let original = try renderer.render(document: document, pixelSize: 128)
        let changed = try renderer.render(document: changedDocument, pixelSize: 128)

        XCTAssertFalse(original === changed)
    }

    @MainActor
    func testMonochromeSymbolColorChangesRenderedImage() throws {
        let transform = LayerTransform(centerX: 0.5, centerY: 0.53, scale: 0.55)
        let redDocument = IconDocument(layers: [
            .symbol(SymbolLayer(
                symbolName: "circle.fill",
                color: ColorValue(red: 0.9, green: 0.2, blue: 0.2),
                transform: transform
            ))
        ])
        let blueDocument = IconDocument(layers: [
            .symbol(SymbolLayer(
                symbolName: "circle.fill",
                color: ColorValue(red: 0.2, green: 0.4, blue: 0.9),
                transform: transform
            ))
        ])

        let redImage = try IconRenderer.shared.render(document: redDocument, pixelSize: 128)
        let blueImage = try IconRenderer.shared.render(document: blueDocument, pixelSize: 128)
        XCTAssertNotEqual(redImage.tiffRepresentation, blueImage.tiffRepresentation)
    }

    @MainActor
    func testMulticolorSymbolColorChangesRenderedImage() throws {
        let transform = LayerTransform(centerX: 0.5, centerY: 0.53, scale: 0.55)
        let redDocument = IconDocument(layers: [
            .symbol(SymbolLayer(
                symbolName: "person.2.fill",
                color: ColorValue(red: 0.9, green: 0.2, blue: 0.2),
                renderingMode: .multicolor,
                transform: transform
            ))
        ])
        let blueDocument = IconDocument(layers: [
            .symbol(SymbolLayer(
                symbolName: "person.2.fill",
                color: ColorValue(red: 0.2, green: 0.4, blue: 0.9),
                renderingMode: .multicolor,
                transform: transform
            ))
        ])

        let redImage = try IconRenderer.shared.render(document: redDocument, pixelSize: 128)
        let blueImage = try IconRenderer.shared.render(document: blueDocument, pixelSize: 128)
        XCTAssertNotEqual(redImage.tiffRepresentation, blueImage.tiffRepresentation)
    }

    @MainActor
    func testLayerOpacityChangesRenderedImage() throws {
        let transform = LayerTransform(centerX: 0.5, centerY: 0.53, scale: 0.55, opacity: 1)
        var transparentTransform = transform
        transparentTransform.opacity = 0
        let opaqueDocument = IconDocument(layers: [
            .symbol(SymbolLayer(symbolName: "circle.fill", transform: transform))
        ])
        let transparentDocument = IconDocument(layers: [
            .symbol(SymbolLayer(symbolName: "circle.fill", transform: transparentTransform))
        ])

        let opaqueImage = try IconRenderer.shared.render(document: opaqueDocument, pixelSize: 128)
        let transparentImage = try IconRenderer.shared.render(document: transparentDocument, pixelSize: 128)
        XCTAssertNotEqual(opaqueImage.tiffRepresentation, transparentImage.tiffRepresentation)
    }

    @MainActor
    func testHiddenLayerDoesNotRender() throws {
        var hiddenTransform = LayerTransform()
        hiddenTransform.isVisible = false
        let visibleDocument = IconDocument(layers: [.symbol(SymbolLayer(symbolName: "star.fill"))])
        let hiddenDocument = IconDocument(layers: [
            .symbol(SymbolLayer(symbolName: "star.fill", transform: hiddenTransform))
        ])

        let visible = try IconRenderer.shared.render(document: visibleDocument, pixelSize: 128)
        let hidden = try IconRenderer.shared.render(document: hiddenDocument, pixelSize: 128)
        XCTAssertNotEqual(visible.tiffRepresentation, hidden.tiffRepresentation)
    }

    @MainActor
    func testLockedLayerCannotBeDeletedOrDuplicated() {
        var transform = LayerTransform()
        transform.isLocked = true
        let layer = IconLayer.symbol(SymbolLayer(symbolName: "star.fill", transform: transform))
        let editor = EditorViewModel()
        editor.document.layers = [layer]
        editor.selectedLayerID = layer.id

        editor.duplicateSelectedLayer()
        editor.deleteSelectedLayer()

        XCTAssertEqual(editor.document.layers, [layer])
    }

    @MainActor
    func testTextColorChangesRenderedImage() throws {
        let transform = LayerTransform(centerX: 0.5, centerY: 0.53, scale: 0.55)
        let redDocument = IconDocument(layers: [
            .text(TextLayer(text: "A", color: ColorValue(red: 0.9, green: 0.2, blue: 0.2), transform: transform))
        ])
        let blueDocument = IconDocument(layers: [
            .text(TextLayer(text: "A", color: ColorValue(red: 0.2, green: 0.4, blue: 0.9), transform: transform))
        ])

        let redImage = try IconRenderer.shared.render(document: redDocument, pixelSize: 128)
        let blueImage = try IconRenderer.shared.render(document: blueDocument, pixelSize: 128)
        XCTAssertNotEqual(redImage.tiffRepresentation, blueImage.tiffRepresentation)
    }

    @MainActor
    func testMovingSelectedLayerChangesLayerOrder() {
        let first = IconLayer.symbol(SymbolLayer(symbolName: "star.fill"))
        let second = IconLayer.symbol(SymbolLayer(symbolName: "heart.fill"))
        let editor = EditorViewModel()
        editor.document.layers = [first, second]
        editor.selectedLayerID = first.id

        editor.moveSelectedLayer(by: 1)

        XCTAssertEqual(editor.document.layers.map(\.id), [second.id, first.id])
    }

    @MainActor
    func testEditorUndoAndRedoRestoreDocumentSnapshots() {
        let editor = EditorViewModel()
        let initialDocument = editor.document

        editor.addText()
        let editedDocument = editor.document
        XCTAssertNotEqual(editedDocument, initialDocument)
        XCTAssertTrue(editor.canUndo)

        editor.undo()
        XCTAssertEqual(editor.document, initialDocument)
        XCTAssertTrue(editor.canRedo)

        editor.redo()
        XCTAssertEqual(editor.document, editedDocument)
    }
}
