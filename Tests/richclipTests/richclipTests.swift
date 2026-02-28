import AppKit
import XCTest

final class richclipTests: XCTestCase {
    override func setUp() {
        super.setUp()
        NSPasteboard.general.clearContents()
    }

    func testListTypes() {
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
        let data = try XCTUnwrap(testString.data(using: .utf8))

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

    func testCustomType() {
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

    func testJsonOutput() throws {
        // Prepare clipboard with a mix of text and simulated binary data
        let textData = "test string".data(using: .utf8)!
        let binaryData = Data([0x00, 0xFF, 0xDE, 0xAD, 0xBE, 0xEF]) // Invalid UTF-8
        let customType = NSPasteboard.PasteboardType("com.example.binary")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(textData, forType: .string)
        pasteboard.setData(binaryData, forType: customType)

        // Find the binary path
        let binaryPath = Bundle.main.bundlePath.components(separatedBy: ".build")[0] + ".build/debug/richclip"
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["list", "--json"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        // Parse JSON
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: String]]
        XCTAssertNotNil(json)

        let stringEntry = json?.first { $0["type"] == "public.utf8-plain-text" }
        XCTAssertEqual(stringEntry?["value"], "test string")

        let binaryEntry = json?.first { $0["type"] == "com.example.binary" }
        XCTAssertEqual(binaryEntry?["value"], binaryData.base64EncodedString())
    }
}
