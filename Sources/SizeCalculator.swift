import Foundation

struct SizeBreakdown {
    var totalBytes: Int64 = 0
    var fileCount: Int = 0
    var folderCount: Int = 0
    var unreadableCount: Int = 0
    /// Top items by size (direct children for a single folder, otherwise the selected items), sorted descending, capped at 5.
    var topItems: [(name: String, bytes: Int64)] = []
}

struct SizeCalculator {
    static func calculateBreakdown(for urls: [URL]) -> SizeBreakdown {
        guard !urls.isEmpty else { return SizeBreakdown() }

        // Single folder selection: one pass that computes both the total and
        // the largest direct children (a mini disk-usage view).
        if urls.count == 1, let url = urls.first, isDirectory(url) {
            return breakdownForSingleFolder(url)
        }

        let counters = Counters()
        var total: Int64 = 0
        var items: [(name: String, bytes: Int64)] = []

        for url in urls {
            let size = totalSize(of: url, counters: counters)
            total += size
            items.append((url.lastPathComponent, size))
        }

        items.sort { $0.bytes > $1.bytes }
        return SizeBreakdown(
            totalBytes: total,
            fileCount: counters.files,
            folderCount: counters.folders,
            unreadableCount: counters.unreadable,
            topItems: Array(items.prefix(5))
        )
    }

    // MARK: - Single folder breakdown

    private static func breakdownForSingleFolder(_ root: URL) -> SizeBreakdown {
        let counters = Counters()
        var total: Int64 = 0
        var buckets: [String: Int64] = [:]

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey],
            options: [],
            errorHandler: { _, _ in counters.unreadable += 1; return true }
        ) else {
            return SizeBreakdown()
        }

        // The enumerator resolves symlinks (e.g. /tmp -> /private/tmp), so
        // compare path components instead of doing naive string math.
        let rootComponents = root.resolvingSymlinksInPath().standardizedFileURL.pathComponents

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey])
            let size = allocatedSize(values)
            total += size

            if values?.isDirectory == true {
                counters.folders += 1
            } else {
                counters.files += 1
            }

            // Bucket each item under its top-level child of the root.
            let components = fileURL.standardizedFileURL.pathComponents
            var i = 0
            while i < rootComponents.count && i < components.count && rootComponents[i] == components[i] {
                i += 1
            }
            if i < components.count {
                let top = components[i]
                buckets[top, default: 0] += size
            }
        }

        let top = buckets.map { (name: $0.key, bytes: $0.value) }
            .sorted { $0.bytes > $1.bytes }

        return SizeBreakdown(
            totalBytes: total,
            fileCount: counters.files,
            folderCount: counters.folders,
            unreadableCount: counters.unreadable,
            topItems: Array(top.prefix(5))
        )
    }

    // MARK: - Helpers

    private static func totalSize(of url: URL, counters: Counters) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if isDir.boolValue {
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey],
                options: [],
                errorHandler: { _, _ in counters.unreadable += 1; return true }
            ) else { return 0 }

            var total: Int64 = 0
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey])
                total += allocatedSize(values)
                if values?.isDirectory == true {
                    counters.folders += 1
                } else {
                    counters.files += 1
                }
            }
            return total
        } else {
            counters.files += 1
            let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey])
            return allocatedSize(values)
        }
    }

    private static func allocatedSize(_ values: URLResourceValues?) -> Int64 {
        if let v = values?.totalFileAllocatedSize { return Int64(v) }
        if let v = values?.fileAllocatedSize { return Int64(v) }
        if let v = values?.fileSize { return Int64(v) }
        return 0
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}

/// Reference-type counters so the enumerator's escaping errorHandler can
/// mutate them safely.
private final class Counters {
    var files = 0
    var folders = 0
    var unreadable = 0
}
