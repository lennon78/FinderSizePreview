import Foundation

struct SizeCalculator {
    static func calculateTotalSize(for urls: [URL]) -> Int64 {
        var totalSize: Int64 = 0
        let fileManager = FileManager.default
        
        for url in urls {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            
            if isDirectory.boolValue {
                guard let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey],
                    options: [],
                    errorHandler: nil
                ) else { continue }
                
                for case let fileURL as URL in enumerator {
                    totalSize += fileSize(for: fileURL)
                }
            } else {
                totalSize += fileSize(for: url)
            }
        }
        
        return totalSize
    }
    
    private static func fileSize(for url: URL) -> Int64 {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey])
            if let totalAllocated = resourceValues.totalFileAllocatedSize {
                return Int64(totalAllocated)
            } else if let allocated = resourceValues.fileAllocatedSize {
                return Int64(allocated)
            } else if let rootSize = resourceValues.fileSize {
                return Int64(rootSize)
            }
        } catch {
            // Silently ignore access errors
        }
        return 0
    }
}
