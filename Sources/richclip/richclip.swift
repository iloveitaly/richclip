import AppKit
import Foundation

@main
struct RichClip {
    static func main() {
        let arguments = CommandLine.arguments

        guard arguments.count > 1 else {
            printUsage()
            exit(0)
        }

        let subcommand = arguments[1]

        switch subcommand {
        case "list":
            listTypes()
        case "copy":
            handleCopy(args: Array(arguments.dropFirst(2)))
        case "paste":
            handlePaste(args: Array(arguments.dropFirst(2)))
        case "--help", "-h":
            printUsage()
        default:
            print("Error: Unknown subcommand '\(subcommand)'")
            printUsage()
            exit(1)
        }
    }

    static func printUsage() {
        print("""
        Usage: richclip <subcommand> [options]

        Subcommands:
          list           Output all available clipboard types (UTIs)
          copy [--type <uti>]  Copy data from stdin to the clipboard
          paste [--type <uti>] Paste data from the clipboard to stdout

        Options:
          --type <uti>   The UTI to use (default: public.utf8-plain-text)
          --help, -h     Show this help information
        """)
    }

    static func listTypes() {
        let pasteboard = NSPasteboard.general
        guard let types = pasteboard.types, !types.isEmpty else {
            fputs("Error: Clipboard is empty\n", stderr)
            exit(1)
        }
        for type in types {
            print(type.rawValue)
        }
    }

    static func handleCopy(args: [String]) {
        var type = NSPasteboard.PasteboardType.string

        if let typeIndex = args.firstIndex(of: "--type"), typeIndex + 1 < args.count {
            type = NSPasteboard.PasteboardType(args[typeIndex + 1])
        }

        let data = FileHandle.standardInput.readDataToEndOfFile()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: type)
    }

    static func handlePaste(args: [String]) {
        var type = NSPasteboard.PasteboardType.string

        if let typeIndex = args.firstIndex(of: "--type"), typeIndex + 1 < args.count {
            type = NSPasteboard.PasteboardType(args[typeIndex + 1])
        }

        let pasteboard = NSPasteboard.general
        guard let data = pasteboard.data(forType: type) else {
            fputs("Error: No data found for type '\(type.rawValue)'\n", stderr)
            exit(1)
        }

        FileHandle.standardOutput.write(data)
    }
}
