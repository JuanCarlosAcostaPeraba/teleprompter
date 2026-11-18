import AppKit
import SwiftUI

@main
@MainActor
struct TeleprompterApp {
    static func main() {
        let app = NSApplication.shared
        let desktop = Desktop()
        app.delegate = desktop
        withExtendedLifetime(desktop) { app.run() }
    }
}

@MainActor
final class Desktop: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var showDock = UserDefaults.standard.object(forKey: "showDock") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(showDock, forKey: "showDock")
            applyDockVisibility()
        }
    }
    @Published var showMenuBar = UserDefaults.standard.object(forKey: "showMenuBar") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(showMenuBar, forKey: "showMenuBar")
            applyMenuVisibility()
        }
    }

    let model = Prompter()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var editor: NSWindow?
    private var settings: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        applyDockVisibility()
        applyMenuVisibility()
        openSettings()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if urls.contains(where: { $0.scheme == "teleprompter" && $0.host == "settings" }) {
            openSettings()
        }
    }

    @objc func openSettings() {
        if settings == nil {
            settings = makeWindow(title: "Ajustes de Teleprompter", size: NSSize(width: 430, height: 390),
                                  content: Preferences(desktop: self, model: model))
        }
        present(settings)
    }

    @objc func openEditor() {
        if editor == nil {
            editor = makeWindow(title: "Teleprompter", size: NSSize(width: 560, height: 410),
                                resizable: true, content: Editor(model: model, openSettings: openSettings))
        }
        present(editor)
    }

    func openReader(fromClipboard: Bool = false) {
        let defaults = UserDefaults.standard
        if fromClipboard {
            guard let text = NSPasteboard.general.string(forType: .string),
                  text.contains(where: { $0.isLetter || $0.isNumber }) else {
                NSSound.beep()
                return
            }
            defaults.set(text, forKey: "script")
        }
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        if model.readerIsVisible && !fromClipboard {
            model.raiseReader()
        } else if let text = defaults.string(forKey: "script"),
                  text.contains(where: { $0.isLetter || $0.isNumber }) {
            model.show(text: text)
            if !model.readerIsVisible { openEditor() }
        } else {
            openEditor()
        }
    }

    private func makeWindow<Content: View>(
        title: String, size: NSSize, resizable: Bool = false, content: Content
    ) -> NSWindow {
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if resizable { style.insert(.resizable) }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: style, backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        if resizable { window.minSize = NSSize(width: 480, height: 350) }
        window.contentView = NSHostingView(rootView: content)
        window.center()
        return window
    }

    private func present(_ window: NSWindow?) {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func applyDockVisibility() {
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
    }

    private func applyMenuVisibility() {
        if showMenuBar && statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = menuIcon()
            item.button?.setAccessibilityLabel("Teleprompter")
            item.button?.toolTip = "Teleprompter"
            item.button?.target = self
            item.button?.action = #selector(togglePopover)
            statusItem = item
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(rootView: QuickControls(desktop: self, model: model))
        } else if !showMenuBar, let statusItem {
            popover.performClose(nil)
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
            popover.contentViewController = nil
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func menuIcon() -> NSImage {
        let icon = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.setStroke()
            let frame = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 3, width: 15, height: 12),
                                     xRadius: 3, yRadius: 3)
            frame.lineWidth = 1.4
            frame.stroke()
            NSColor.black.setFill()
            for (y, width) in [(6.3, 5.0), (8.4, 9.0), (10.6, 6.0)] {
                NSBezierPath(roundedRect: NSRect(x: 4.5, y: y, width: width, height: 1.2),
                             xRadius: 0.6, yRadius: 0.6).fill()
            }
            return true
        }
        icon.isTemplate = true
        return icon
    }

    private func installMainMenu() {
        let main = NSMenu()
        let applicationItem = NSMenuItem()
        main.addItem(applicationItem)
        let application = NSMenu(title: "Teleprompter")
        applicationItem.submenu = application
        let preferences = application.addItem(withTitle: "Ajustes…", action: #selector(openSettings), keyEquivalent: ",")
        preferences.target = self
        let script = application.addItem(withTitle: "Editar guion", action: #selector(openEditor), keyEquivalent: "e")
        script.target = self
        application.addItem(.separator())
        application.addItem(withTitle: "Salir de Teleprompter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edición")
        editItem.submenu = edit
        edit.addItem(withTitle: "Deshacer", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Pegar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Seleccionar todo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
    }
}
