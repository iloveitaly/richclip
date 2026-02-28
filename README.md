# Inspect and Manipulate macOS Clipboard UTIs

richclip is a native macOS command-line tool that gives you granular control over your clipboard data. While standard tools like `pbcopy` and `pbpaste` only handle plain text, richclip allows you to inspect, read, and write any Uniform Type Identifier (UTI) format, such as `public.html`, `public.png`, or `com.adobe.pdf`.

I built this because I often needed to debug what exactly was on my pasteboard when building web integrations or Raycast extensions. It's written in Swift with zero external runtime dependencies, utilizing the native `NSPasteboard` API.

## Installation

You can install richclip using [mise](https://mise.jdx.dev/):

```bash
mise use -g ubi:iloveitaly/richclip@latest
```

Alternatively, you can download the universal binary from the [latest release](https://github.com/iloveitaly/richclip/releases) and place it in your `$PATH`.

## Usage

The tool is designed to be smart. It detects if you are piping data in or out to determine whether to copy or paste.

### Basic Commands

```bash
# List all available UTIs on the clipboard with their contents in JSON
richclip list --json

# Copy plain text (implicit copy because of stdin)
echo "hello world" | richclip

# Paste plain text (implicit paste)
richclip

# Copy specific HTML content
echo "<b>Bold</b>" | richclip --type public.html

# Paste specific HTML content
richclip --type public.html
```

### Advanced Inspection

Use the `list` subcommand to see exactly what's on your clipboard:

```bash
# Just list the UTIs
richclip list

# Get a full JSON breakdown of types and values (base64 for binary)
richclip list --json
```

## Features

* **Universal Binary**: Runs natively on both Intel and Apple Silicon Macs.
* **Implicit Actions**: Automatically switches between copy and paste based on `stdin` presence.
* **JSON Output**: Inspect complex clipboard states including binary data encoded as Base64.
* **Smart Default Paste**: Prioritizes plain text but falls back to the "richest" available UTI if text isn't present.
* **Zero Dependencies**: A single standalone Swift binary that uses native macOS APIs.

## [MIT License](LICENSE.md)
