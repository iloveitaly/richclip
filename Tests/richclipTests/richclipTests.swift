import AppKit
import XCTest

final class richclipTests: XCTestCase {
    override func setUp() {
        super.setUp()
        NSPasteboard.general.clearContents()
    }

    func testListTypes() throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("test", forType: .string)

        guard let types = pasteboard.types else {
            XCTFail("No types found in pasteboard")
            return
        }

        XCTAssertTrue(types.contains(.string))
    }

    func testCopyAndPasteString() throws {
        let testString = "Hello, World!"
        let type = NSPasteboard.PasteboardType.string
        let data = testString.data(using: .utf8)!

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: type)

        guard let retrievedData = pasteboard.data(forType: type) else {
            XCTFail("Could not retrieve data from pasteboard")
            return
        }

        let retrievedString = String(data: retrievedData, encoding: .utf8)
        XCTAssertEqual(testString, retrievedString)
    }

    func testCustomType() throws {
        let testData = "custom data".data(using: .utf8)!
        let customType = NSPasteboard.PasteboardType("com.example.custom")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(testData, forType: customType)

        guard let retrievedData = pasteboard.data(forType: customType) else {
            XCTFail("Could not retrieve custom data from pasteboard")
            return
        }

        XCTAssertEqual(testData, retrievedData)
    }

    func testBinaryOutput() throws {
        // Ensure there is something in the clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("test", forType: .string)

        // Find the binary path
        let binaryPath = Bundle.main.bundlePath.components(separatedBy: ".build")[0] + ".build/debug/richclip"

        // Skip if binary doesn't exist (e.g. running from Xcode without build)
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["list"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertFalse(output.isEmpty)
    }

    func testEmptyClipboardError() throws {
        // Clear clipboard
        NSPasteboard.general.clearContents()

        // Find the binary path
        let binaryPath = Bundle.main.bundlePath.components(separatedBy: ".build")[0] + ".build/debug/richclip"
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["list"]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 1)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(errorOutput.contains("Error: Clipboard is empty"))
    }
}
