import AppKit
import SwiftUI

@MainActor
enum CameraPlacement {
    static let defaultReaderWidth = 435.0
    static let defaultReaderHeight = 216.0
    static let readerWidthRange = 400.0...1200.0
    static let readerHeaderHeight = 16.0

    static func previewSize(width: Double) -> NSSize {
        NSSize(width: width, height: defaultReaderHeight)
    }

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

struct AudioNoticeSurface: ViewModifier {
    let useLiquidGlass: Bool
    let fallback: Color

    func body(content: Content) -> some View {
        if #available(macOS 26, *), useLiquidGlass {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            content.background(fallback, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ListenButtonAppearance: ViewModifier {
    let useLiquidGlass: Bool
    let highlight: Color
    let ink: Color

    func body(content: Content) -> some View {
        if #available(macOS 26, *), useLiquidGlass {
            content.buttonStyle(.glass).foregroundStyle(highlight)
        } else {
            content.buttonStyle(.borderedProminent)
                .tint(highlight.opacity(0.75))
                .foregroundStyle(ink)
        }
    }
}

extension ClosedRange where Bound == Double {
    func clamp(_ value: Double) -> Double {
        Swift.min(upperBound, Swift.max(lowerBound, value))
    }
}
