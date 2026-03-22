import AppKit

private func observerCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let instance = Unmanaged<FinderObserver>.fromOpaque(refcon).takeUnretainedValue()
    instance.handleNotification(notification)
}

class FinderObserver {
    private var observer: AXObserver?
    private var runLoopSource: CFRunLoopSource?
    
    var onSelectionChanged: (() -> Void)?
    
    func startObserving() {
        if observer != nil { return } // Already observing
        
        guard let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else { return }
        let pid = finderApp.processIdentifier
        let finderElement = AXUIElementCreateApplication(pid)
        
        let contextPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        var newObserver: AXObserver?
        let result = AXObserverCreate(pid, observerCallback, &newObserver)
        
        if result == .success, let obs = newObserver {
            self.observer = obs
            
            // Add notifications for selection changes
            AXObserverAddNotification(obs, finderElement, kAXSelectedChildrenChangedNotification as CFString, contextPtr)
            AXObserverAddNotification(obs, finderElement, kAXFocusedUIElementChangedNotification as CFString, contextPtr)
            AXObserverAddNotification(obs, finderElement, kAXMainWindowChangedNotification as CFString, contextPtr)
            
            self.runLoopSource = AXObserverGetRunLoopSource(obs)
            if let rls = self.runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, .defaultMode)
            }
        }
    }
    
    func stopObserving() {
        if let obs = observer, let rls = runLoopSource {
            AXObserverRemoveNotification(obs, AXUIElementCreateApplication(0), kAXSelectedChildrenChangedNotification as CFString)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), rls, .defaultMode)
        }
        self.observer = nil
        self.runLoopSource = nil
    }
    
    fileprivate func handleNotification(_ notification: CFString) {
        // Debounce or dispatch immediately
        DispatchQueue.main.async {
            self.onSelectionChanged?()
        }
    }
}
