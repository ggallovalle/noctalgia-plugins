# Plan: CopyQ Clipboard Plugin for Noctalia

## Overview

Fork the official Noctalia `clipboard` plugin (which uses [cliphist](https://github.com/sentriz/cliphist)) to use [CopyQ](https://github.com/hluk/copyq) as the clipboard history backend instead.

**Plugin ID**: `copyq-clipboard`
**Min Noctalia Version**: `4.1.2`

## Why CopyQ?

CopyQ is a clipboard manager with a persistent daemon and CLI interface. It provides more features than cliphist (tabs, tags, notes, scripting) but for this plugin we use only its basic history functionality.

## Key Differences from Original Plugin

| Aspect | Original (cliphist) | CopyQ Version |
|--------|---------------------|---------------|
| Backend | CLI tool (stateless) | Daemon + CLI |
| Item IDs | Stable numeric IDs (e.g., "123") | Positional indices (0, 1, 2...) |
| Remove | `cliphist delete` via stdin pipe | `copyq remove <index>` |
| Wipe | `cliphist wipe` | `copyq eval 'while(size()>0) remove(0)'` |
| Pinned items | Store {preview, type} + reference by ID | Store {preview, type, content} snapshot |
| Image decode | `cliphist decode <id> > file.png` | `copyq read image/png <index> > file.png` |
| Copy item | `cliphist decode <id> | wl-copy` | `copyq select <index>` |

## Data Model

### Original cliphist model

```json
items: [
  { "id": "123", "preview": "some text", "type": "text" },
  { "id": "456", "preview": "[[ binary data ... ]]", "type": "image" }
]
```

- IDs are stable across refreshes
- `remove("456")` works by grepping `^456\t` from list output
- Pinned items reference by ID

### CopyQ model

```json
items: [
  { "id": 0, "preview": "some text", "type": "text" },
  { "id": 1, "preview": "[[ binary data ... ]]", "type": "image" }
]
```

- `id` is the positional index
- When item 0 is removed, item 1 becomes item 0 (indices shift)
- Pinned items **must store content directly** because references by index break on deletion

## File Structure

```
copyq-clipboard/
├── manifest.json      # Plugin metadata (id: "copyq-clipboard")
├── Main.qml           # Backend: CopyQ CLI integration (PRIMARY CHANGE)
├── BarWidget.qml      # From original (unchanged)
├── Panel.qml          # From original (unchanged)
├── ClipboardItem.qml  # From original (unchanged)
├── Settings.qml       # From original (unchanged)
├── i18n/
│   └── en.json        # From original (unchanged)
├── preview.png        # From original
├── README.md          # This plugin's documentation
└── PLAN.md            # This file
```

## Main.qml Changes

### 1. List Command

Original:
```bash
cliphist list | head -n 100
```

CopyQ equivalent:
```bash
copyq eval '
var s = size();
var limit = pluginSettings.maxHistorySize;
for (var i = 0; i < s && i < limit; i++) {
    var text = str(read(i));
    var mime = data(i).mime;
    // Output: index\tmime\tpreview
    print(i + "\t" + mime + "\t" + text);
}
'
```

Output format: `index\tmime\tpreview`
- Text: `0\ttext/plain\thello world`
- Image: `1\timage/png\t[[ binary data ... ]]`

### 2. Type Detection

Instead of cliphist's `[[ binary data ... WxH ]]` pattern, detect MIME type:

```javascript
const mimeRx = /^image\//;
const fileRx = /^text\/uri-list$/;

if (mimeRx.test(mime)) {
    type = "image";
} else if (fileRx.test(mime) || preview.startsWith("file://") || preview.startsWith("/")) {
    type = "file";
} else {
    type = "text";
}
```

### 3. Image Decode

```bash
copyq read image/png <id> > /tmp/clipboard-<id>.png
```

Same LRU cache pattern as original.

### 4. Copy Item to Clipboard

```bash
copyq select <id>
```

For pinned items (which store content directly):
```bash
copyq copy <mime> - <<< "$content"
```

### 5. Remove Item

```bash
copyq remove <id>
```

Note: Index-based, so after removal indices shift.

### 6. Wipe History

```bash
copyq eval 'while(size() > 0) remove(0)'
```

### 7. CopyQ Availability Check

On `onPluginApiChanged`, run `copyq size`. If it fails, set `copyQAvailable: false`.

In Panel.qml, check this flag and show a banner:
```
"CopyQ is not running. Start it with: copyq &"
```

## Pinned Items Changes

Original stores: `{ preview, type }` with reference by cliphist ID

CopyQ version stores: `{ preview, type, content }`
- `content`: For text, the actual text. For images, base64-encoded image data or path to cached image.

When copying a pinned item:
- Text: `copyq copy - <<< "$content"`
- Image: Write cached image to temp, `copyq copy image/png - < file`

## Manifest.json

```json
{
  "id": "copyq-clipboard",
  "name": "CopyQ Clipboard",
  "version": "1.0.0",
  "minNoctaliaVersion": "4.1.2",
  "author": "kbroom",
  "repository": "https://github.com/kbroom/noctalia-plugins",
  "license": "MIT",
  "description": "Clipboard history panel backed by CopyQ.",
  "tags": ["Utility", "Bar", "Panel"],
  "entryPoints": {
    "main": "Main.qml",
    "barWidget": "BarWidget.qml",
    "panel": "Panel.qml",
    "settings": "Settings.qml"
  },
  "dependencies": {
    "plugins": []
  },
  "metadata": {
    "defaultSettings": {
      "maxHistorySize": 100,
      "showImagePreviews": true,
      "density": "comfortable"
    }
  }
}
```

## Dependencies

- Noctalia `4.1.2`+
- [CopyQ](https://github.com/hluk/copyq) (must be installed and running)
- Wayland compositor with `wl-clipboard` for clipboard operations (usually comes with CopyQ)

## Installation

1. Install CopyQ: `sudo apt install copyq` (Debian/Ubuntu) or your distro's package manager
2. Start CopyQ daemon: `copyq &` (or enable autostart)
3. Add this repository to Noctalia's custom plugin repositories, or clone directly:
   ```bash
   git clone https://github.com/kbroom/noctalia-plugins ~/path/to/noctalia-plugins
   ```
4. Open Noctalia Settings → Plugins and install `copyq-clipboard`

## Implementation Order

1. Create repository structure with LICENSE, README, PLAN.md
2. Create `manifest.json`
3. Implement `Main.qml` (the main work)
4. Copy `BarWidget.qml`, `Panel.qml`, `ClipboardItem.qml`, `Settings.qml` from original (unchanged)
5. Copy `i18n/en.json` from original
6. Copy `preview.png` from original
7. Write `copyq-clipboard/README.md`
8. Test the plugin

## IPC Commands

| Command | Effect |
|---|---|
| `toggle` | Open/close the panel |
| `wipe` | Clear history |

```bash
qs -c noctalia-shell ipc call plugin:copyq-clipboard <command>
```