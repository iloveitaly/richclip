# Swift CLI Engineering & Distribution Playbook

This document is a comprehensive retrospective and blueprint for building, testing, and distributing native Swift command-line tools. It details not just *what* to do, but *why*, capturing the dead ends, workarounds, and elegant solutions discovered during the development of a production-grade macOS CLI.

## 1. Project Initialization & Dependency Management

### Toolchain: `mise` is Mandatory
We use [`mise`](https://mise.jdx.dev/) as the definitive source of truth for all environment dependencies.

**What we learned:**
*   **The Toolchain:** A standard Swift project requires `swift`, `just` (for task running), and `swiftformat` (for linting/formatting).
*   **Mise Configuration:** 
    ```toml
    [tools]
    just = "latest"
    swift = "6.1"
    swiftformat = { version = "latest", no_app = "true", rename_exe = "swiftformat" }
    ```
*   **The `.swift-version` Gotcha:** `swiftformat` will emit warnings and silently disable certain formatting features if it cannot infer the Swift compiler version. You **must** include a `.swift-version` file at the root of the repo (e.g., containing `6.1`).
*   **CI Integration:** When using `jdx/mise-action@v3` in GitHub Actions, `install: true` is the default behavior. However, because the `swift` plugin for mise is currently considered experimental, you **must** explicitly pass `experimental: true` to the action, otherwise the CI will fail to install Swift.

### `Package.swift` Setup
When initializing with `swift package init --type executable`, pay close attention to the `swift-tools-version` at the top of `Package.swift`. 
*   **What went wrong:** We initialized locally with `6.2`, but GitHub Actions macOS runners only supported `6.1`. This caused immediate CI failures.
*   **The Fix:** Always downgrade the `swift-tools-version` in `Package.swift` to match the lowest common denominator between your local `mise` environment and GitHub Actions (e.g., `6.0` or `6.1`).

## 2. CLI Architecture & Argument Parsing

### Escaping `CommandLine.arguments`
*   **What went wrong:** Initially, we manually parsed `CommandLine.arguments` and used array slicing (`arguments.dropFirst(2)`) to extract flags. This is brittle, error-prone, and provides no built-in help text.
*   **The Fix:** Apple's `swift-argument-parser` is the gold standard. It provides declarative struct-based routing, type-safe options, and automatic generation of highly polished `--help` menus.

### The "Implicit Subcommand" Pattern
We wanted the CLI to be smart: if a user pipes data in (`echo "text" | cli`), it should implicitly copy. If they just run the command (`cli`), it should implicitly paste.
*   **What went wrong:** We initially tried to remove `@main` from the parser, inspect arguments manually, and then mutate the array to inject "copy" or "paste" before handing it to the parser. This was hacky. Then, we tried manually instantiating the `Copy()` and `Paste()` structs and calling `.run()` on them. This failed with runtime crashes because `swift-argument-parser`'s `@Option` and `@Flag` property wrappers are not initialized until the parsing phase completes.
*   **The Elegant Solution:** Put `@main` on the root `ParsableCommand` struct. Add a `mutating func run() throws` to the root struct. This method is executed *only* if the user provides no subcommands. Inside this method, we can safely execute our default fallback logic.
*   **POSIX Stdin Check:** To detect if data is being piped, `isatty(STDIN_FILENO) == 0` is the bulletproof C-level check available in Foundation.

## 3. macOS Frameworks (`AppKit` & `NSPasteboard`)

### The `declareTypes` Gotcha
When interacting with `NSPasteboard` to write custom or private UTIs (like `org.chromium.web-custom-data`), simply using `setData(_:forType:)` is insufficient. If the type is not known to the system, macOS will either drop the data or incorrectly map it to a standard string type.
*   **The Fix:** You **must** call `declareTypes([yourType], owner: nil)` *after* clearing the pasteboard and *before* setting the data. This registers the precise UTI for that payload.

### Handling Raw Binary Data
When building CLIs that pipe binary data into AppKit frameworks, standard `stdin`/`stdout` pipelines can mangle null bytes or UTF-16 strings.
*   **The Fix:** Read raw data directly via `FileHandle.standardInput.readDataToEndOfFile()`. To make the CLI scriptable without shell corruption, provide a `--base64` flag that allows the user to ingest/export binary blobs encoded safely as Base64 strings.

## 4. Testing Strategies (`XCTest`)

### Binary Integration Testing
You don't just want to test internal functions; you want to test the compiled binary.
*   **The Pattern:** Use `Process()` and `Pipe()` to invoke the compiled binary.
*   **Locating the Binary:** During `swift test`, the binary is built but not in the standard `$PATH`. You can locate it programmatically:
    ```swift
    let binaryPath = Bundle.main.bundlePath.components(separatedBy: ".build")[0] + ".build/debug/your_app"
    ```

### Strict Linting in Tests
`swiftformat` enforces strict rules that catch common bad habits in test files:
*   **No Force Unwrapping:** Writing `let data = string.data(using: .utf8)!` in a test is an anti-pattern. `swiftformat` will flag this. Use `let data = try XCTUnwrap(string.data(using: .utf8))` instead.
*   **Redundant Throws:** Do not mark test functions as `throws` if they do not contain `try` statements.

## 4. Automation via `Just`

We use `just` to unify commands across local and CI environments.
*   **Lint vs. Format:** 
    *   `just fmt` executes `swiftformat .` to auto-fix code.
    *   `just lint` executes `swiftformat . --lint` to fail with an exit code if formatting is violated (used in CI).
*   **Repository as Code:** We pulled patterns from `iloveitaly/python-package-template` to manage GitHub settings via the CLI. We use a `metadata.json` file as the source of truth for the repo description, homepage, and topics.
    *   `just github_setup` wraps `gh` CLI commands to push this metadata to GitHub, establish branch protection rules for `master`, and configure Actions permissions.

## 5. CI/CD & Distribution Pipeline

### Matrix & Verification (`ci.yml`)
Run `just lint`, `just test`, and `just build` on every push to `master` and every pull request.

### Universal Binaries
*   **The Old Way:** Compiling for Intel, compiling for Apple Silicon, and using `lipo` to stitch them together.
*   **The Modern Way:** Swift Package Manager handles this natively. A single command generates a "fat" binary:
    ```bash
    swift build -c release --arch arm64 --arch x86_64
    ```

### Packaging Assets
When zipping the binary for GitHub Releases, use `zip -j` (junk paths). If you don't, the ZIP file will contain the entire `.build/apple/Products/Release/` directory tree, confusing end users.

### Versioning with `release-please`
We use `googleapis/release-please-action` to automatically generate changelogs and GitHub Releases based on Conventional Commits (e.g., `feat:`, `fix:`).
*   **What we learned:** `release-please` does **not** natively support a `swift` release type. Attempting to use `release-type: swift` will crash the action.
*   **The Fix:** Use `release-type: simple`. This is the standard fallback for unsupported languages. It manages the Release PRs and GitHub Releases perfectly based purely on Git history.
*   **Simplicity:** We initially tried configuring complex `release-please-config.json` and manifest files. We discovered it was overkill. By simply passing `release-type: simple` to the GitHub Action, `release-please` operates statelessly and seamlessly without cluttering the repository root with config files.

## Summary Checklist for Next Project
1. `swift package init --type executable`
2. Define `.swift-version` and `mise.toml` immediately.
3. Import `swift-argument-parser`.
4. Copy `Justfile` and `.github/workflows/` (with `experimental: true` for mise).
5. Build Universal Binaries natively.
6. Use `release-type: simple` for `release-please`.