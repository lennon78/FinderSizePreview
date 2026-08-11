import AppKit
import SwiftUI
import HotKey
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var hotKey: HotKey?
    var hudWindow: NSWindow?
    var statusItem: NSStatusItem?
    var keyMonitor: Any?
    let viewModel = HUDViewModel()
    let finderObserver = FinderObserver()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupHUDWindow()
        setupKeyMonitor()
        
        // Initial quiet check. ONLY register hotkey if we already have permission!
        if checkAccessibilityPermissions(quiet: true) {
            registerHotKey()
        }
    }
    
    func registerHotKey() {
        // Register Control + Shift + Space global hotkey
        hotKey = HotKey(key: .space, modifiers: [.control, .shift])
        hotKey?.keyDownHandler = { [weak self] in
            self?.toggleHUD()
        }
    }
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: "Finder Size Preview") 
                     ?? NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Finder Size Preview")
            button.image = image
            if image == nil {
                button.title = "Size Preview"
            }
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Finder Size Preview", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check Permissions", action: #selector(forceCheckPermissions), keyEquivalent: "p"))
        
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        if #available(macOS 13.0, *) {
            launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        menu.addItem(launchItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    sender.state = .off
                } else {
                    try SMAppService.mainApp.register()
                    sender.state = .on
                }
            } catch {
                print("Failed to toggle Launch at Login: \(error.localizedDescription)")
                let alert = NSAlert()
                alert.messageText = "Launch Registration Failed"
                alert.informativeText = "macOS blocks automatic login registration for apps that aren't stored in the main Applications folder.\n\nTo fix this: Please locate FinderSizePreview.app and move it to your 'Applications' folder, or add it manually in System Settings -> General -> Login Items."
                alert.addButton(withTitle: "OK")
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "macOS Version Unsupported"
            alert.informativeText = "Automatic Launch at Login is only supported on macOS 13 or newer. Please configure manually in System Settings."
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
    
    @objc func forceCheckPermissions() {
        // 1. Check Accessibility
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "Step 1: Accessibility Permission"
            alert.informativeText = "To use the hotkey, please enable FinderSizePreview in Accessibility.\n\nNote: If the app does not automatically appear in the list, click the [+] button at the bottom and manually add FinderSizePreview.app."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Close")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        } else {
            // Already have accessibility. Register hotkey if not already registered!
            if hotKey == nil {
                registerHotKey()
            }
        }
        
        // 2. Check Automation (Finder)
        let script = NSAppleScript(source: "tell application \"Finder\" to get version")
        var error: NSDictionary? = nil
        script?.executeAndReturnError(&error)
        
        if let err = error {
            if let errNum = err[NSAppleScript.errorNumber] as? Int, errNum == -1743 {
                let alert = NSAlert()
                alert.messageText = "Step 2: Automation Permission"
                alert.informativeText = "To get the selected file size, this app needs to communicate with Finder. Please toggle the 'Finder' switch under FinderSizePreview in the Automation settings."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Close")
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                        NSWorkspace.shared.open(url)
                    }
                }
                return
            }
        }
        
        // All good!
        let alert = NSAlert()
        alert.messageText = "Permissions Granted!"
        alert.informativeText = "Both Accessibility and Automation permissions are successfully configured. You can now press Control + Shift + Space."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        // Accessibility is NOT needed for right-click menu. So we just proceed.
        if urls.count == 1 && urls[0].scheme == "findersizepreview" {
            toggleHUD()
        } else {
            // Direct file launch via open -a
            if hudWindow?.isVisible == true {
                viewModel.update(result: .success(urls))
            } else {
                showHUD(with: .success(urls))
            }
        }
    }
    
    /// Local monitor so ⌘C copies and Esc dismisses while the HUD is up.
    /// (The HUD panel is nonactivating, so SwiftUI keyboard shortcuts alone
    /// are not reliable here.)
    func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.hudWindow, window.isVisible else { return event }

            // ⌘C — copy the summary to the clipboard
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "c" {
                self.viewModel.copyToClipboard()
                return nil
            }

            // Esc — dismiss the HUD
            if event.keyCode == 53 {
                self.toggleHUD()
                return nil
            }

            return event
        }
    }

    func setupHUDWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 220),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.center()
        
        let hostingView = NSHostingView(rootView: HUDView(viewModel: viewModel))
        panel.contentView = hostingView
        
        self.hudWindow = panel
    }
    
    func windowWillClose(_ notification: Notification) {
        finderObserver.stopObserving()
    }
    
    func checkAccessibilityPermissions(quiet: Bool = false) -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: !quiet]
        return AXIsProcessTrustedWithOptions(options)
    }
    
    func toggleHUD() {
        guard let window = hudWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
            finderObserver.stopObserving()
        } else {
            let result = FinderIntegration.getSelectedItems()
            showHUD(with: result)
        }
    }
    
    func refreshHUD() {
        let result = FinderIntegration.getSelectedItems()
        viewModel.update(result: result)
    }
    
    func showHUD(with result: Result<[URL], FinderError>) {
        guard let window = hudWindow else { return }
        
        viewModel.update(result: result)
        
        if !window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            finderObserver.onSelectionChanged = { [weak self] in
                self?.refreshHUD()
            }
            finderObserver.startObserving()
        }
    }
}
