# Copyhog

A lightweight macOS menu bar clipboard manager. Copyhog silently captures text and image copies, watches for screenshots, and gives you quick access to your clipboard history — all from a small popover in the menu bar.

## Features

- Clipboard history for text and images (up to 20 items)
- Automatic screenshot detection and organization
- Single-click to re-copy any item
- Multi-select batch copy
- Drag-and-drop items into other apps
- Global hotkey (Shift+Cmd+C) to toggle the popover from any app
- Launches at login and runs silently in the background

## Requirements

- macOS 13.0 (Ventura) or later

## Download & Install

### Option 1: Download the Release

1. Go to the [Releases](../../releases) page
2. Download the latest `Copyhog.dmg` or `Copyhog.zip`
3. Open the downloaded file
4. Drag **Copyhog.app** into your `/Applications` folder
5. Launch Copyhog from Applications or Spotlight

### Option 2: Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/dbrelesky/Copyhog.git
   cd Copyhog
   ```

2. Open the Xcode project:
   ```bash
   open Copyhog/Copyhog.xcodeproj
   ```

3. Select your signing team in Xcode:
   - Select the **Copyhog** target
   - Go to **Signing & Capabilities**
   - Choose your Apple Developer team (or Personal Team)

4. Build and run with **Cmd+R**, or archive for distribution via **Product > Archive**

## Setup

On first launch, Copyhog will:

1. **Appear in your menu bar** — look for the pig snout icon in the top-right of your screen
2. **Request Accessibility permissions** — required for the global hotkey to work. Grant access in **System Settings > Privacy & Security > Accessibility**
3. **Register as a login item** — Copyhog will start automatically when you log in

### Granting Accessibility Access

If the global hotkey (Shift+Cmd+C) doesn't work:

1. Open **System Settings**
2. Go to **Privacy & Security > Accessibility**
3. Find **Copyhog** in the list and toggle it **on**
4. If Copyhog isn't listed, click the **+** button and add it from `/Applications`

## Usage

- **Click the menu bar icon** to open the clipboard history popover
- **Shift+Cmd+C** to toggle the popover from any app
- **Click an item** to copy it back to your clipboard
- **Hover over an item** to see a full-size preview
- **Drag an item** out of the popover into any target app
- **Multi-select mode** — click the select button to enable checkboxes, then batch copy multiple items

## Uninstall

1. Quit Copyhog (right-click the menu bar icon or force quit)
2. Delete `Copyhog.app` from `/Applications`
3. Optionally remove stored data:
   ```bash
   rm -rf ~/Library/Application\ Support/Copyhog
   rm -rf ~/Documents/Screenies
   ```
