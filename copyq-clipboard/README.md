# CopyQ Clipboard

A clipboard history panel for the [Noctalia](https://github.com/noctalia-dev/noctalia-shell) shell. Backed by [CopyQ](https://github.com/hluk/copyq) instead of cliphist.

![preview](preview.png)

## Features

- **History panel** — searchable, scrollable clipboard history accessible from the status bar
- **Tabs** — switch between Text, Images, and Files views with keyboard shortcuts (1 / 2 / 3)
- **Search** — filter history in real time by content
- **Pinning** — pin entries to keep them at the top across sessions and reboots
- **Timestamps** — relative timestamps shown on every entry (e.g. "2 min ago")
- **Image previews** — inline thumbnails for image entries (toggleable)
- **Settings panel** — configure the plugin from Noctalia Settings
- **IPC commands** — `toggle` and `wipe` for compositor keybind integration

## Requirements

- Noctalia `4.1.2`+
- [CopyQ](https://github.com/hluk/copyq) **installed and running**
- Wayland compositor

## Installation

1. Install CopyQ:
   ```bash
   # Debian/Ubuntu
   sudo apt install copyq

   # Fedora
   sudo dnf install copyq

   # Arch Linux
   sudo pacman -S copyq
   ```

2. Start CopyQ daemon (or add to your compositor's autostart):
   ```bash
   copyq &
   ```

3. Open **Noctalia Settings → Plugins**, add this repository as a custom plugin source, and install **CopyQ Clipboard**.

## Development

To run a local checkout:

```bash
git clone https://github.com/kbroom/noctalia-plugins ~/path/to/copyq-clipboard
qs kill -c noctalia-shell; sleep 1; qs -d -c noctalia-shell
```

## Settings

| Key | Default | Description |
|---|---|---|
| `maxHistorySize` | `100` | Maximum number of entries in history. |
| `showImagePreviews` | `true` | Show image thumbnails inline. |
| `density` | `"comfortable"` | Visual density: `"compact"`, `"comfortable"`, or `"spacious"`. |

## IPC

| Command | Effect |
|---|---|
| `toggle` | Open/close the panel on the focused screen. |
| `wipe` | Clear history without opening the panel. |

```bash
qs -c noctalia-shell ipc call plugin:copyq-clipboard <command>
```

## Keybinds

### Niri

```kdl
spawn-at-startup "qs" "-d" "-c" "noctalia-shell"

binds {
    Mod+V { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:copyq-clipboard" "toggle"; }
    Mod+Shift+V { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:copyq-clipboard" "wipe"; }
}
```

### Hyprland

```ini
bindr = SUPER, V, exec, qs -c noctalia-shell ipc call plugin:copyq-clipboard toggle
bindr = SUPER SHIFT, V, exec, qs -c noctalia-shell ipc call plugin:copyq-clipboard wipe
```

## Troubleshooting

**"CopyQ is not running" banner**: CopyQ daemon must be running. Start it with `copyq &` or configure your compositor to auto-start it.

**No clipboard history**: Ensure CopyQ is monitoring the clipboard. Right-click the CopyQ tray icon → "Preferences" → "Clipboard" tab → enable "Copy to clipboard in normal mode".

## License

MIT.