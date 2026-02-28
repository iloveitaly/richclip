import AppKit
import ArgumentParser
import Foundation

@main
struct RichClip: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "richclip",
        abstract: "A native macOS clipboard tool with granular UTI type control.",
        subcommands: [List.self, Copy.self, Paste.self]
    )
}

extension RichClip {
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Output all available clipboard types (UTIs)")

        @Flag(name: .shortAndLong, help: "Output types and values in JSON format")
        var json: Bool = false

        func run() throws {
            let pasteboard = NSPasteboard.general
            guard let types = pasteboard.types, !types.isEmpty else {
                fputs("Error: Clipboard is empty\n", stderr)
                throw ExitCode(1)
            }

            if json {
                var results: [[String: String]] = []
                for type in types {
                    let value: String
                    if let data = pasteboard.data(forType: type) {
                        // Attempt to decode as UTF-8 string, fallback to base64 for binary
                        if let string = String(data: data, encoding: .utf8) {
                            value = string
                        } else {
                            value = data.base64EncodedString()
                        }
                    } else {
                        value = ""
                    }
                    results.append(["type": type.rawValue, "value": value])
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let jsonData = try encoder.encode(results)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } else {
                for type in types {
                    print(type.rawValue)
                }
            }
        }
    }

    struct Copy: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Copy data from stdin to the clipboard")

        @Option(name: .shortAndLong, help: "The UTI to use")
        var type: String = "public.utf8-plain-text"

        func run() throws {
            let pasteboardType = NSPasteboard.PasteboardType(type)
            let data = FileHandle.standardInput.readDataToEndOfFile()

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(data, forType: pasteboardType)
        }
    }

    struct Paste: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Paste data from the clipboard to stdout")

        @Option(name: .shortAndLong, help: "The UTI to use (defaults to plain text if available)")
        var type: String?

        func run() throws {
            let pasteboard = NSPasteboard.general
            let pasteboardType: NSPasteboard.PasteboardType

            if let type = type {
                pasteboardType = NSPasteboard.PasteboardType(type)
            } else if let types = pasteboard.types, !types.isEmpty {
                // Default to plain text if it exists, otherwise use the first available type
                if types.contains(.string) {
                    pasteboardType = .string
                } else {
                    pasteboardType = types[0]
                }
            } else {
                fputs("Error: Clipboard is empty\n", stderr)
                throw ExitCode(1)
            }

            guard let data = pasteboard.data(forType: pasteboardType) else {
                fputs("Error: No data found for type '\(pasteboardType.rawValue)'\n", stderr)
                throw ExitCode(1)
            }

            FileHandle.standardOutput.write(data)
        }
    }

}
