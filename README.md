# Windows PATH Restorer & Dev Environment Manager

A self-contained Windows batch/PowerShell utility that scans your drives for installed developer tools and restores missing entries to your `PATH` environment variable—without hitting the 1,024-character `setx` truncation limit.

## Features

- **Registry-Safe & Variable Expansion Preservation (`dotnet/runtime#1438` Fix):**
  - Uses direct Win32 registry APIs (`RegistryValueOptions.DoNotExpandEnvironmentNames`) rather than `.NET`'s `[Environment]::SetEnvironmentVariable`, which notoriously corrupts `REG_EXPAND_SZ` into flat `REG_SZ` strings and expands `%VAR%` variables prematurely.
  - Preserves unexpanded `%SystemRoot%`, `%USERPROFILE%`, and `%APPDATA%` variables in the final saved list.
  - Automatically detects and repairs existing `REG_SZ` (String) `Path` keys back to `REG_EXPAND_SZ` (ExpandString).
- **Automatic Desktop Backup:**
  - Exports a timestamped snapshot (`PATH_Backup_YYYY-MM-DD_HH-mm-ss.txt`) of both User and System `PATH` variables (including their registry value types) to your Desktop before making any changes.
- **Core Windows Health Check:**
  - Detects and repairs missing core OS paths (`%SystemRoot%\System32`, `%SystemRoot%`, `%SystemRoot%\System32\Wbem`, `%SystemRoot%\System32\WindowsPowerShell\v1.0`).
- **Comprehensive C++ Toolchain & Developer Discovery:**
  - **C / C++ & Native Build Tools:** MinGW / GCC (`gcc.exe`), C++ MinGW G++ (`g++.exe`), MSVC C++ (`cl.exe`, preferring native 64-bit `Hostx64\x64`), LLVM / Clang++ (`clang++.exe`), CMake (`cmake.exe`), Ninja (`ninja.exe`), and Emscripten (`emcc.bat`).
  - **Runtimes & SDKs:** Python (plus `\Scripts`), Node.js, npm Global, Git, Java JDK, Go, Rust (Cargo), PHP, Composer, .NET SDK, Docker, FFmpeg, VS Code CLI, and Android ADB.
  - **Custom Drive & App Roots:** Scans local drives, standard program directories, custom roots (`C:\Main Data\Apps`, `C:\Main\Apps`, `C:\msys64`, `C:\mingw64`, `C:\LLVM`), and targeted Visual Studio / BuildTools directories.
- **Interactive Version Selection & Prioritization:**
  - When multiple versions of a tool/compiler are found, choose which version to add or prepend to the front of `PATH`.
- **Headless & Non-Interactive Automation:**
  - Supports non-interactive automated execution via `-NonInteractive`, `-Silent`, `/y`, or environment variable `PATH_RESTORER_NONINTERACTIVE=1`.
- **Dead Path Cleanup & Instant Refresh:**
  - Safely normalizes entries to identify broken/non-existent folders, deduplicates paths, and broadcasts `WM_SETTINGCHANGE` so updates apply immediately to newly opened terminals.

## How to Use

### Interactive Mode
1. Download or clone `ultimate_path_restorer.bat`.
2. Double-click the file to run it (or right-click and select **Run as administrator** if core `System32` paths need to be restored to the System `PATH`).
3. Follow the on-screen prompts to select preferred tool versions and clean up dead entries.
4. Open a **new** Command Prompt, PowerShell, or terminal window to verify your restored tools (e.g., `g++ --version`, `cmake --version`, `ninja --version`, `python --version`).

### Non-Interactive / Scripted Mode
Run from PowerShell or Command Prompt:
```bat
ultimate_path_restorer.bat -NonInteractive
```
Or set the environment variable:
```powershell
$env:PATH_RESTORER_NONINTERACTIVE = '1'
.\ultimate_path_restorer.bat
```
