import AppKit
import SwiftUI

struct ReaderText: NSViewRepresentable {
    @ObservedObject var model: Prompter
    let size: CGSize

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let coordinator = context.coordinator
        coordinator.seek = { [weak model] in model?.seek($0) }
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true
        scroll.documentView = coordinator.textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.update(model: model, size: size, scroll: scroll)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let storage = NSTextStorage()
        private let layout = NSLayoutManager()
        private let container = NSTextContainer()
        let textView: NSTextView
        var seek: ((Int) -> Void)?

        private var ranges: [NSRange] = []
        private var renderedScript: UUID?
        private var renderedFontSize = 0.0
        private var renderedColor: NSColor?
        private var renderedSize = CGSize.zero
        private var renderedCursor = -1
        private var lastAnchor: CGFloat?
        private let readColor = NSColor.white.withAlphaComponent(0.62)

        override init() {
            storage.addLayoutManager(layout)
            layout.addTextContainer(container)
            container.lineFragmentPadding = 0
            textView = NSTextView(frame: .zero, textContainer: container)
            super.init()
            textView.delegate = self
            textView.drawsBackground = false
            textView.isEditable = false
            textView.isSelectable = true
            textView.isRichText = true
            textView.isVerticallyResizable = false
            textView.textContainerInset = NSSize(width: 22, height: 4)
            textView.linkTextAttributes = [:]
        }

        func update(model: Prompter, size: CGSize, scroll: NSScrollView) {
            guard size.width > 48, size.height > 0 else { return }
            let font = NSFont.systemFont(ofSize: model.fontSize, weight: .medium)
            let highlight = NSColor(model.highlightColor)
            let rebuild = renderedScript != model.scriptID || renderedFontSize != model.fontSize
                || renderedColor != highlight
            let resized = renderedSize != size
            let moved = renderedCursor != model.cursor
            guard rebuild || resized || moved else { return }

            if rebuild {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = 5
                let base: [NSAttributedString.Key: Any] = [
                    .font: font, .foregroundColor: NSColor.white, .paragraphStyle: paragraph
                ]
                let text = NSMutableAttributedString(string: "\n", attributes: base)
                ranges.removeAll(keepingCapacity: true)
                for token in model.script.tokens {
                    var attributes = base
                    if let index = token.wordIndex {
                        let color = index == model.cursor ? highlight : index < model.cursor ? readColor : .white
                        attributes[.foregroundColor] = color
                        attributes[.link] = URL(string: "teleprompter://\(index)")
                        ranges.append(NSRange(location: text.length, length: token.text.utf16.count))
                    } else if token.text.hasPrefix("[") {
                        attributes[.foregroundColor] = highlight.withAlphaComponent(0.72)
                    }
                    text.append(NSAttributedString(string: token.text, attributes: attributes))
                }
                storage.setAttributedString(text)
                renderedScript = model.scriptID
                renderedFontSize = model.fontSize
                renderedColor = highlight
            } else if moved {
                storage.beginEditing()
                let first = max(0, min(renderedCursor, model.cursor))
                let last = min(ranges.count - 1, max(renderedCursor, model.cursor))
                if first <= last {
                    for index in first...last {
                        let color = index == model.cursor ? highlight : index < model.cursor ? readColor : .white
                        storage.addAttribute(.foregroundColor, value: color, range: ranges[index])
                    }
                }
                storage.endEditing()
            }

            let inset = textView.textContainerInset.width
            if resized || rebuild {
                container.containerSize = NSSize(width: size.width - 2 * inset, height: .greatestFiniteMagnitude)
                layout.ensureLayout(for: container)
                let height = layout.usedRect(for: container).maxY + size.height
                textView.setFrameSize(NSSize(width: size.width, height: height))
                renderedSize = size
            }
            renderedCursor = model.cursor
            guard !ranges.isEmpty else { return }

            // Keep one prior line above the active word and leave room to align
            // the final line even when the bottom of the script is in view.
            let range = ranges[min(model.cursor, ranges.count - 1)]
            let glyph = layout.glyphIndexForCharacter(at: range.location)
            let lineTop = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
            let contextHeight = layout.defaultLineHeight(for: font) + 5
            let target = max(0, lineTop - contextHeight)
            if rebuild || resized || lastAnchor != target {
                scroll.contentView.scroll(to: NSPoint(x: 0, y: target))
                scroll.reflectScrolledClipView(scroll.contentView)
                lastAnchor = target
            }
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL, url.scheme == "teleprompter",
                  let host = url.host, let index = Int(host) else { return false }
            seek?(index)
            return true
        }
    }
}
