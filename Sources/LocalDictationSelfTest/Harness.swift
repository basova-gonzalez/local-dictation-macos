import Foundation

// Minimal assertion harness. XCTest and swift-testing are unavailable under
// Command Line Tools only, so the automated checks run as a plain
// executable: it records pass/fail and exits non-zero if anything failed.
final class Harness: @unchecked Sendable {
    private let lock = NSLock()
    private var passed = 0
    private var failed = 0
    private var failures: [String] = []

    func check(_ name: String, _ condition: Bool) {
        lock.lock(); defer { lock.unlock() }
        if condition {
            passed += 1
        } else {
            failed += 1
            failures.append(name)
        }
    }

    func report() -> Never {
        lock.lock()
        let p = passed, f = failed, list = failures
        lock.unlock()
        var out = "self-test: \(p) passed, \(f) failed\n"
        for name in list { out += "  FAIL: \(name)\n" }
        FileHandle.standardOutput.write(Data(out.utf8))
        exit(f == 0 ? EXIT_SUCCESS : EXIT_FAILURE)
    }
}
