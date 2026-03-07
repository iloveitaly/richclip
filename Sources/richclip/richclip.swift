import AppKit
import ArgumentParser
import Foundation

struct SharedOptions: ParsableArguments {
    @Option(name: .shortAndLong, help: "The UTI to use")
    var type: String?

    @Flag(name: .customLong("base64"), help: "Decode stdin from Base64 (copy) or encode stdout to Base64 (paste)")
    var base64: Bool = false
}

@main
struct RichClip: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "richclip",
        abstract: "A native macOS clipboard tool with granular UTI type control. Ideal for enabling LLMs to inspect all clipboard formats.",
        discussion: "More info at https://github.com/iloveitaly/richclip",
        // x-release-please-version
        version: "1.1.0",
        subcommands: [List.self, Copy.self, Paste.self],
    )

    @OptionGroup var shared: SharedOptions

    mutating func run() throws {
        // Only run smart logic if no subcommand is provided.
        // swift-argument-parser only calls this run() if no subcommand matched.

        // If interactive (TTY), we should definitely paste.
        if isatty(STDIN_FILENO) == 1 {
            var pasteCommand = Paste()
            pasteCommand.shared = shared
            try pasteCommand.run()
            return
        }

        // If not interactive (pipe or file), read stdin and decide.
        let data = FileHandle.standardInput.readDataToEndOfFile()
        if !data.isEmpty {
            // Non-empty stdin: Copy
            var copyCommand = Copy()
            copyCommand.shared = shared
            copyCommand.dataToCopy = data
            try copyCommand.run()
        } else {
            // Empty stdin: Paste
            var pasteCommand = Paste()
            pasteCommand.shared = shared
            try pasteCommand.run()
        }
    }
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
                    let value: String = if let data = pasteboard.data(forType: type) {
                        // Attempt to decode as UTF-8 string, fallback to base64 for binary
                        if let string = String(data: data, encoding: .utf8) {
                            string
                        } else {
                            data.base64EncodedString()
                        }
                    } else {
                        ""
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

        @OptionGroup var shared: SharedOptions

        // Optional data passed from the root command's smart logic
        var dataToCopy: Data?

        func run() throws {
            let typeToUse = shared.type ?? "public.utf8-plain-text"
            let pasteboardType = NSPasteboard.PasteboardType(typeToUse)

            var data = dataToCopy ?? FileHandle.standardInput.readDataToEndOfFile()

            if shared.base64 {
                guard let decodedData = Data(base64Encoded: data, options: .ignoreUnknownCharacters) else {
                    fputs("Error: Input is not valid Base64\n", stderr)
                    throw ExitCode(1)
                }
                data = decodedData
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            // CRITICAL: Declare the type before setting data. This ensures custom or non-standard
            // UTIs are registered correctly and not mapped to a default string format.
            pasteboard.declareTypes([pasteboardType], owner: nil)

            let success = pasteboard.setData(data, forType: pasteboardType)
            if !success {
                fputs("Error: Failed to set data for type '\(pasteboardType.rawValue)'. The format might be invalid or unsupported by the clipboard.\n", stderr)
                throw ExitCode(1)
            }
        }
    }

    struct Paste: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Paste data from the clipboard to stdout")

        @OptionGroup var shared: SharedOptions

        func run() throws {
            let pasteboard = NSPasteboard.general
            let pasteboardType: NSPasteboard.PasteboardType

            if let type = shared.type {
                pasteboardType = NSPasteboard.PasteboardType(type)
            } else if let types = pasteboard.types, !types.isEmpty {
                // Default to the first (richest) type available.
                // Standard macOS practice is to put the richest representation first.
                pasteboardType = types[0]
            } else {
                fputs("Error: Clipboard is empty\n", stderr)
                throw ExitCode(1)
            }

            guard let data = pasteboard.data(forType: pasteboardType) else {
                let availableTypes = pasteboard.types?.map { $0.rawValue }.joined(separator: ", ") ?? "none"
                fputs("Error: No data found for type '\(pasteboardType.rawValue)'. Available types: \(availableTypes)\n", stderr)
                throw ExitCode(1)
            }

            if shared.base64 {
                let base64String = data.base64EncodedString()
                if let base64Data = base64String.data(using: .utf8) {
                    FileHandle.standardOutput.write(base64Data)
                }
            } else {
                FileHandle.standardOutput.write(data)
            }
        }
    }
}
