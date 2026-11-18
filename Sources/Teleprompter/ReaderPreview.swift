import AppKit
import SwiftUI

@MainActor
enum CameraPlacement {
    static let previewSize = NSSize(width: 660, height: 204)

    static var screen: NSScreen? {
        NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return CGDisplayIsBuiltin(id.uint32Value) != 0
        } ?? NSScreen.main
    }

    static func position(size: NSSize, on screen: NSScreen) -> NSPoint {
        let bounds = screen.visibleFrame
        return NSPoint(x: max(bounds.minX, bounds.midX - size.width / 2), y: bounds.maxY - 12)
    }
}

struct ReaderSurface: ViewModifier {
    let blur: Bool
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if blur { Rectangle().fill(.ultraThinMaterial).opacity(opacity) }
                    Color(red: 0.06, green: 0.09, blue: 0.15).opacity((blur ? 0.68 : 1) * opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 19))
            .overlay { RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(0.16)) }
            .preferredColorScheme(.dark)
    }
}

struct ReaderPreview: View {
    @ObservedObject var model: Prompter

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Vista previa · Teleprompter", systemImage: "text.alignleft")
                .font(.caption.weight(.semibold))
                .foregroundStyle(model.highlightColor)
            Group {
                if Locale(identifier: model.locale).language.languageCode?.identifier == "es" {
                    Text("Así ").foregroundStyle(model.highlightColor) +
                    Text("se verá el guion mientras lees.").foregroundStyle(.white)
                } else {
                    Text("This ").foregroundStyle(model.highlightColor) +
                    Text("is how your script will look as you read.").foregroundStyle(.white)
                }
            }
            .font(.system(size: model.fontSize, weight: .medium))
            .lineSpacing(5)
            .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(ReaderSurface(blur: model.blurBackground, opacity: model.opacity))
    }
}
