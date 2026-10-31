import AppKit
import SwiftUI

struct EmojiTextField: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> EmojiInputField {
        let field = EmojiInputField()
        field.placeholderString = "点击输入 Emoji"
        field.delegate = context.coordinator
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: EmojiInputField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text = field.stringValue
        }
    }
}

final class EmojiInputField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let becameFirstResponder = super.becomeFirstResponder()
        if becameFirstResponder {
            DispatchQueue.main.async {
                NSApp.orderFrontCharacterPalette(nil)
            }
        }
        return becameFirstResponder
    }
}
