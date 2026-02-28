This project plan outlines the development of `clipboard-cli`, a native, zero-dependency macOS tool to inspect and manipulate the clipboard with granular control over data types (UTIs).

### **1. Project Overview**

* **Goal:** Create a lightweight command-line utility to `list`, `read`, and `write` specific clipboard data types (e.g., `public.html`, `public.png`) that standard tools like `pbcopy` cannot handle.
* **Philosophy:** "Zero Dependencies." The tool will be written in Swift and utilize macOS's native `NSPasteboard` API, ensuring it works on any Mac without `brew` installs or third-party binaries.

---

### **2. Core Architecture**

The tool will be a single Swift file (`clipboard-cli.swift`) that acts as a direct interface to the macOS Clipboard API.

* **Language:** Swift (Standard Library + Cocoa).
* **Key API:** `NSPasteboard.general`.
* **Data Flow:**
* **Input:** `stdin` (for writing) or Command Line Arguments (for reading/listing).
* **Output:** `stdout` (raw bytes). *Crucial for piping binary data like images.*



---

### **3. Execution Plan**

#### **Phase 1: The Core Tool (Swift)**

Develop the standalone script that performs the heavy lifting.

* **Task A: List Capability**
* Iterate `NSPasteboard.general.types`.
* Output: Newline-separated list of UTIs (e.g., `public.html`, `com.apple.webarchive`).


* **Task B: Read Capability**
* Accept a UTI argument (e.g., `public.html`).
* Retrieve data using `pasteboard.data(forType:)`.
* Write raw data to `FileHandle.standardOutput` (avoids string encoding corruption).


* **Task C: Write Capability**
* Accept a UTI argument.
* Read raw bytes from `FileHandle.standardInput`.
* Set data using `pasteboard.setData(_:forType:)`.



#### **Phase 2: Raycast Integration**

Connect the Swift tool to the Raycast scripting environment.

* **Strategy:** Embed the Swift code directly into the Bash script as a "Here Doc" or a helper function. This keeps the extension portable (single file).
* **Workflow:**
1. **Pandoc Filter:** Sanitize Markdown (e.g., fix headers).
2. **Conversion:** Convert Markdown → HTML.
3. **Clipboard Injection:** Use the Swift logic to inject `public.html` (for Google Docs) and `public.utf8-plain-text` (for code editors) simultaneously.



#### **Phase 3: Optimization & Distribution**

* **Compilation (Optional but recommended):**
* Add a check to compile the Swift script to a binary (`swiftc -O tool.swift -o tool`) on the first run.
* Benefit: Reduces execution time from ~250ms to ~10ms.


* **Alias Setup:**
* Add `alias cb="~/path/to/clipboard-cli"` to `~/.zshrc` for easy terminal access.



---

### **4. Development Roadmap**

| Step | Action | Output |
| --- | --- | --- |
| **1** | **Prototype** | Create `clipboard.swift` with basic `list` command. |
| **2** | **I/O Handling** | Implement `FileHandle` logic to safely pipe binary data (images/PDFs). |
| **3** | **Raycast Integration** | Port the logic into your "Markdown to Docs" script. |
| **4** | **Testing** | Verify `public.html` pastes correctly into Google Docs vs VS Code. |

---

## **Related**

Here are the tools and resources referenced during our research:

**Existing Tools (Reference Only):**

* **[pngpaste](https://www.google.com/search?q=https://github.com/jcsalter/pngpaste):** Standard tool for pasting images from clipboard to file.
* **[clippy](https://github.com/neilberkman/clippy):** A modern (experimental) clipboard tool for terminal <-> finder integration.
* **[macos-pasteboard (pbv)](https://github.com/chbrown/macos-pasteboard):** The older, unmaintained tool that inspired this project.
* **[impbcopy](https://github.com/akmassey/impbcopy):** The abandoned Objective-C tool often used for this task in the past.

**Documentation:**

* **[NSPasteboard Apple Developer Docs](https://developer.apple.com/documentation/appkit/nspasteboard):** Official API reference.
* **[Uniform Type Identifiers (UTIs)](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/understanding_utis/understand_utis_intro/understand_utis_intro.html):** List of standard types like `public.html`.

Here is a video explaining the complexity of how the macOS Clipboard works (UTIs) and why a tool like this is necessary.

... [Deep dive into macOS Clipboard UTIs](https://www.google.com/search?q=https://www.youtube.com/watch%3Fv%3DQS02yW9F-FY) ...

This video is relevant because it visualizes the hidden data structures (UTIs) your tool will be manipulating.