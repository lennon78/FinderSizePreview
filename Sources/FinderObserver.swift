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
    private var finderElement: AXUIElement?
    private var pendingRefresh: DispatchWorkItem?

    var onSelectionChanged: (() -> Void)?

    func startObserving() {
        if observer != nil { return } // Already observing

        guard let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else { return }
        let pid = finderApp.processIdentifier
        let finderElement = AXUIElementCreateApplication(pid)
        self.finderElement = finderElement

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
        pendingRefresh?.cancel()
        pendingRefresh = nil
        if let obs = observer, let element = finderElement {
            AXObserverRemoveNotification(obs, element, kAXSelectedChildrenChangedNotification as CFString)
            AXObserverRemoveNotification(obs, element, kAXFocusedUIElementChangedNotification as CFString)
            AXObserverRemoveNotification(obs, element, kAXMainWindowChangedNotification as CFString)
        }
        if let rls = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), rls, .defaultMode)
        }
        self.observer = nil
        self.runLoopSource = nil
        self.finderElement = nil
    }

    fileprivate func handleNotification(_ notification: CFString) {
        // The three AX notifications (selection, focus, main window) fire in
        // bursts for a single user action. Coalesce them into one refresh so
        // we don't recalculate sizes several times in a row.
        pendingRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onSelectionChanged?()
        }
        pendingRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
}
