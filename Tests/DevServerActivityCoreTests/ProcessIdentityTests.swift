import Darwin
import XCTest
@testable import DevServerActivityCore

final class ProcessIdentityTests: XCTestCase {
    func testReadsStableIdentityForCurrentProcess() throws {
        let provider = DarwinProcessIdentityProvider()
        let pid = Int(getpid())

        let first = try XCTUnwrap(provider.identity(for: pid))
        let second = try XCTUnwrap(provider.identity(for: pid))

        XCTAssertEqual(first, second)
        XCTAssertGreaterThan(first.startTimeSeconds, 0)
    }

    func testRejectsInvalidPID() {
        let provider = DarwinProcessIdentityProvider()

        XCTAssertNil(provider.identity(for: 0))
        XCTAssertNil(provider.identity(for: -1))
    }
}
