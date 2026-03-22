import Foundation

struct FinderError: Error {
    let message: String
}

struct FinderIntegration {
    static func getSelectedItems() -> Result<[URL], FinderError> {
        let scriptSource = """
        tell application "Finder"
            set theSelection to selection
            set pathList to {}
            repeat with anItem in theSelection
                try
                    set end of pathList to POSIX path of (anItem as text)
                on error
                    try
                        set end of pathList to POSIX path of (anItem as alias)
                    end try
                end try
            end repeat
            return pathList
        end tell
        """
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            let output = script.executeAndReturnError(&error)
            if error == nil {
                var urls: [URL] = []
                let count = output.numberOfItems
                if count > 0 {
                    for i in 1...count {
                        if let path = output.atIndex(i)?.stringValue {
                            urls.append(URL(fileURLWithPath: path))
                        }
                    }
                } else if let path = output.stringValue {
                    urls.append(URL(fileURLWithPath: path))
                }
                return .success(urls)
            } else {
                if let errNum = error?[NSAppleScript.errorNumber] as? Int, errNum == -1743 {
                    return .failure(FinderError(message: "Missing Finder Automation Permission."))
                }
                return .failure(FinderError(message: "AppleScript Error: \(error?[NSAppleScript.errorMessage] as? String ?? "Unknown")"))
            }
        }
        return .failure(FinderError(message: "Failed to initialize script"))
    }
}
