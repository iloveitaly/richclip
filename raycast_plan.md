# Raycast Integration Plan: Clipboard Viewer

This document outlines how to use `richclip` with Raycast to build a granular clipboard viewer and manager.

## 1. Overview
Raycast extensions can execute shell commands and render the output in a user-friendly UI. By leveraging `richclip list --json`, an extension can provide a list of all data formats currently stored in the system pasteboard.

## 2. Technical Architecture

### Data Fetching
The extension will execute:
```bash
richclip list --json
```

### Parsing the Output
The JSON output is an array of objects:
```json
[
  { "type": "public.utf8-plain-text", "value": "..." },
  { "type": "public.html", "value": "..." },
  { "type": "public.png", "value": "iVBORw0KG..." }
]
```

## 3. Handling Binary Data (Images/PDFs)

Since `richclip` encodes non-text data as **Base64**, the Raycast extension must decode this data for display or further processing.

### Displaying Images in Raycast
Raycast's `List.Item` and `Detail` components support images via data URIs. 

**Logic for Image UTIs (e.g., `public.png`, `public.jpeg`):**
1. Identify the UTI as an image type.
2. Prefix the Base64 string with the appropriate MIME type header.
3. Use the result as the `source` for an `Image` component.

**Example (TypeScript/React):**
```typescript
const item = json.find(i => i.type === "public.png");
const dataUri = `data:image/png;base64,${item.value}`;

// Use in Raycast UI
<Detail markdown={`![Clipboard Image](${dataUri})`} />
```

### Writing Binary Data Back to Files
To save a binary UTI (like a PDF) to disk:
1. Extract the Base64 string.
2. Decode it into a Buffer.
3. Write the Buffer to a file.

```typescript
const pdfItem = json.find(i => i.type === "com.adobe.pdf");
const buffer = Buffer.from(pdfItem.value, 'base64');
fs.writeFileSync('output.pdf', buffer);
```

## 4. Proposed Raycast UI Features

| Feature | Logic |
| --- | --- |
| **Format List** | Show all available UTIs in a `List`. |
| **Live Preview** | Show a `Detail` pane with rendered HTML or the Image data URI. |
| **Inspect Raw** | Show the raw string or Base64 content for debugging. |
| **Selective Copy** | A button to re-copy a *specific* UTI back to the clipboard using `richclip copy --type <uti>`. |

## 5. Performance Considerations
- **Binary Size:** For very large clipboards (e.g., a 20MB high-res image), parsing the full JSON string in Node.js can be memory-intensive.
- **Optimization:** If only metadata is needed, consider adding a `richclip list` (non-JSON) to show types first, and then fetch the specific value only when an item is selected using `richclip paste --type <uti>`.
