# FinderSizePreview

A lightweight macOS menu-bar utility that shows you the **total size of whatever you've selected in Finder** — instantly, in a floating HUD overlay.

Finder shows you how many items are selected, but not how much disk space they actually take up. **FinderSizePreview** fills that gap: select a folder or a bunch of files, press `Control + Shift + Space`, and see the combined size at a glance.

![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Features

- **Instant size preview** — calculates the real on-disk size (including subfolders) of your current Finder selection.
- **Global hotkey** — press `Control + Shift + Space` from anywhere to toggle the HUD.
- **Live refresh** — the HUD stays open and updates automatically as you change your selection in Finder.
- **Right-click Quick Action** — also available from Finder's context menu as *Preview File Size*.
- **Menu-bar app** — no Dock icon, sits quietly in your status bar.
- **Launch at Login** option (macOS 13+).
- Human-friendly units: **Bytes / KiB / MiB / GiB**.

---

## Requirements

- macOS 13.0 or later (Ventura+)
- Swift 5.9+ (to build)

---

## Installation

### 1. Build the app

```bash
git clone https://github.com/lennon78/FinderSizePreview.git
cd FinderSizePreview
./build_app.sh
```

This produces `FinderSizePreview.app` in the project directory.

> **Tip:** For the *Launch at Login* option to work, macOS requires the app to live in the `/Applications` folder. Move `FinderSizePreview.app` there after building.

### 2. Grant permissions

FinderSizePreview needs two privacy permissions to work:

1. **Accessibility** — required for the global hotkey.
2. **Automation (Finder)** — required to read the current Finder selection.

The app walks you through both. You can also re-trigger the setup any time from the menu bar: **FinderSizePreview → Check Permissions**.

> **Note:** If the app doesn't appear in the Accessibility list automatically, click the **`+`** button in *System Settings → Privacy & Security → Accessibility* and add `FinderSizePreview.app` manually.

### 3. (Optional) Install the Quick Action

To add the **Preview File Size** right-click action to Finder:

```bash
python3 install_quick_action.py --app "$(pwd)/FinderSizePreview.app"
```

If the new action doesn't show up in the context menu right away, run:

```bash
/System/Library/CoreServices/pbs -update
```

---

## Usage

1. Select one or more files/folders in Finder.
2. Press **`Control + Shift + Space`** — a HUD appears showing the item name(s) and total size.
3. Change your selection to see the size update live.
4. Press the hotkey again (or close the window) to dismiss the HUD.

Alternatively, right-click any selection in Finder and choose **Quick Actions → Preview File Size**.

---

## How it works

- The **global hotkey** is registered with the [`HotKey`](https://github.com/soffes/HotKey) package.
- The current Finder selection is retrieved via AppleScript (Automation permission).
- Total size is computed with `FileManager`'s directory enumerator, preferring the real allocated on-disk size (`totalFileAllocatedSize`).
- An Accessibility observer (`FinderObserver`) listens for selection changes while the HUD is open, so the size refreshes live.
- The HUD is a floating, non-activating `NSPanel` with a `SwiftUI` view — it never steals focus from Finder.

---

## Building from source

The project is a Swift Package Manager executable target:

```bash
swift build -c release
```

The build bundle script (`build_app.sh`) wraps this into a proper `.app` bundle with a generated `Info.plist`.

### Project layout

```
Sources/
├── main.swift              # App entry point (accessory / no-Dock app)
├── AppDelegate.swift       # Hotkey, status bar, HUD window, permissions
├── HUDView.swift           # SwiftUI HUD UI + view model
├── FinderIntegration.swift # Reads the current Finder selection
├── FinderObserver.swift    # Live selection-change observation
└── SizeCalculator.swift    # Recursive on-disk size calculation
build_app.sh                # Builds FinderSizePreview.app
install_quick_action.py     # Installs the right-click Quick Action
```

---

## License

[MIT](LICENSE)
