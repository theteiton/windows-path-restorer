# Windows PATH Restorer & Dev Environment Manager

A self-contained Windows batch/PowerShell utility that scans your drives for installed developer tools and restores missing entries to your `PATH` environment variable—without hitting the 1,024-character `setx` truncation limit.

## Features
- **Automatic Desktop Backup:** Exports a timestamped snapshot (`PATH_Backup_YYYY-MM-DD_HH-mm-ss.txt`) of both User and System `PATH` variables to your Desktop before making any changes.
- **Core Windows Health Check:** Detects and repairs missing core OS paths (`System32`, `Wbem`, `WindowsPowerShell`).
- **Multi-Drive Tool Discovery:** Scans active local drives for **Python** (plus `\Scripts`), **Node.js**, **npm**, **Git**, **Java JDK**, **Go**, **Rust (Cargo)**, **PHP**, **Composer**, **.NET SDK**, **CMake**, **MinGW/GCC**, **FFmpeg**, **Docker**, **VS Code CLI**, and **Android ADB**.
- **Interactive Multi-Version Selection:** When multiple versions of a runtime (e.g., Python 3.10 and 3.12) are installed, lets you choose which one to add and whether to place it at the top of `PATH` for priority.
- **Dead Path Cleanup & Instant Refresh:** Removes broken/non-existent folders, deduplicates entries, and broadcasts `WM_SETTINGCHANGE` so changes apply immediately to new terminals.

## How to Use
1. Download `ultimate_path_restorer.bat`.
2. Double-click the file to run it (or right-click and select **Run as administrator** if core `System32` paths need to be restored to the System `PATH`).
3. Follow the on-screen prompts to select preferred tool versions and clean up dead entries.
4. Open a **new** Command Prompt, PowerShell, or terminal window to verify your restored tools (e.g., `python --version`).
