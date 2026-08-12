import XCTest
@testable import FinderSizePreview

final class ByteFormatterTests: XCTestCase {
    func testBytes() {
        XCTAssertEqual(ByteFormatter.string(from: 0), "0 Bytes")
        XCTAssertEqual(ByteFormatter.string(from: 1023), "1023 Bytes")
    }

    func testKiB() {
        XCTAssertEqual(ByteFormatter.string(from: 1024), "1.00 KiB")
        XCTAssertEqual(ByteFormatter.string(from: 1536), "1.50 KiB")
    }

    func testMiB() {
        XCTAssertEqual(ByteFormatter.string(from: 1048576), "1.00 MiB")
        XCTAssertEqual(ByteFormatter.string(from: 5_242_880), "5.00 MiB")
    }

    func testGiB() {
        XCTAssertEqual(ByteFormatter.string(from: 1_073_741_824), "1.00 GiB")
    }

    func testTiB() {
        XCTAssertEqual(ByteFormatter.string(from: 1_099_511_627_776), "1.00 TiB")
        // Just below a TiB stays in GiB
        XCTAssertEqual(ByteFormatter.string(from: 1_099_511_627_775), "1024.00 GiB")
    }

    func testCount() {
        XCTAssertEqual(ByteFormatter.count(1234), "1,234")
        XCTAssertEqual(ByteFormatter.count(0), "0")
    }
}
