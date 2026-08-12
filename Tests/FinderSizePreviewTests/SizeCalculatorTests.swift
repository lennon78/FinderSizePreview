import XCTest
@testable import FinderSizePreview

final class SizeCalculatorTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("fsp_tests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func makeFile(named name: String, in dir: URL? = nil, bytes: Int) throws -> URL {
        let parent = dir ?? root!
        let url = parent.appendingPathComponent(name)
        try Data(repeating: 0x41, count: bytes).write(to: url)
        return url
    }

    func testEmptySelection() {
        let result = SizeCalculator.calculateBreakdown(for: [])
        XCTAssertEqual(result.totalBytes, 0)
        XCTAssertTrue(result.topItems.isEmpty)
        XCTAssertEqual(result.fileCount, 0)
    }

    func testMissingPathDoesNotCrash() {
        let url = root.appendingPathComponent("does_not_exist")
        let result = SizeCalculator.calculateBreakdown(for: [url])
        XCTAssertEqual(result.totalBytes, 0)
        XCTAssertEqual(result.fileCount, 0)
    }

    func testSingleFile() throws {
        try makeFile(named: "a.txt", bytes: 100)
        let result = SizeCalculator.calculateBreakdown(for: [root.appendingPathComponent("a.txt")])
        XCTAssertEqual(result.fileCount, 1)
        XCTAssertEqual(result.folderCount, 0)
        XCTAssertEqual(result.topItems.first?.name, "a.txt")
        XCTAssertGreaterThanOrEqual(result.totalBytes, 100)
    }

    func testSingleFolderRollsUpNestedContent() throws {
        let big = root.appendingPathComponent("big")
        let nested = big.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        for i in 0..<3 {
            try makeFile(named: "f\(i).bin", in: big, bytes: 1_000_000)
        }
        try makeFile(named: "deep.bin", in: nested, bytes: 800_000)

        let result = SizeCalculator.calculateBreakdown(for: [root])
        XCTAssertEqual(result.fileCount, 4) // 3 + 1 nested
        XCTAssertEqual(result.folderCount, 2) // big + nested
        XCTAssertEqual(result.topItems.first?.name, "big")
        XCTAssertGreaterThanOrEqual(result.topItems.first?.bytes ?? 0, 3_000_000 + 800_000)
        XCTAssertEqual(result.unreadableCount, 0)
    }

    func testMultiSelectionSortedDescending() throws {
        let small = try makeFile(named: "small.txt", bytes: 100_000)
        let big = root.appendingPathComponent("big")
        try FileManager.default.createDirectory(at: big, withIntermediateDirectories: true)
        try makeFile(named: "x.bin", in: big, bytes: 2_000_000)

        let result = SizeCalculator.calculateBreakdown(for: [small, big])
        XCTAssertEqual(result.topItems.first?.name, "big")
        XCTAssertEqual(result.topItems.last?.name, "small.txt")
        let sizes = result.topItems.map(\.bytes)
        XCTAssertEqual(sizes, sizes.sorted(by: >))
    }

    func testDuplicateNamesKeptSeparate() throws {
        let dirA = root.appendingPathComponent("dirA")
        let dirB = root.appendingPathComponent("dirB")
        try FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)
        try makeFile(named: "dup.txt", in: dirA, bytes: 100_000)
        try makeFile(named: "dup.txt", in: dirB, bytes: 200_000)

        let result = SizeCalculator.calculateBreakdown(
            for: [dirA.appendingPathComponent("dup.txt"), dirB.appendingPathComponent("dup.txt")]
        )
        XCTAssertEqual(result.topItems.filter { $0.name == "dup.txt" }.count, 2)
        XCTAssertGreaterThanOrEqual(result.totalBytes, 300_000)
    }
}
