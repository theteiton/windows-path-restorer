@echo off
setlocal
title Ultimate Windows PATH Restorer & Dev Environment Manager
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "$raw = Get-Content -LiteralPath '%~f0' -Raw -Encoding UTF8; $marker = '#__PS_' + 'START__'; $ps = $raw.Substring($raw.LastIndexOf($marker)); $sb = [scriptblock]::Create($ps); & $sb %*"
if /i not "%~1"=="-NonInteractive" if /i not "%~1"=="-Silent" if /i not "%~1"=="/y" if not "%PATH_RESTORER_NONINTERACTIVE%"=="1" pause
exit /b
#__PS_START__

param([string[]]$ScriptArgs = $args)

$ErrorActionPreference = 'SilentlyContinue'

$isNonInteractive = ($env:PATH_RESTORER_NONINTERACTIVE -eq '1') -or
                    ($ScriptArgs -contains '-NonInteractive') -or ($ScriptArgs -contains '-Silent') -or
                    ($ScriptArgs -contains '/y') -or ($ScriptArgs -contains '-y') -or
                    ($args -contains '-NonInteractive') -or ($args -contains '-Silent') -or
                    ($args -contains '/y') -or ($args -contains '-y')

$cleanDead = ($ScriptArgs -contains '-CleanDead') -or ($args -contains '-CleanDead')

# ---------------------------------------------------------
# Registry Helpers: Fix dotnet/runtime#1438 & Preserve %VAR%
# ---------------------------------------------------------
function Get-RawRegistryPathInfo([string]$scope) {
    $subKeyPath = if ($scope -eq 'Machine') {
        'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    } else {
        'Environment'
    }
    $root = if ($scope -eq 'Machine') { [Microsoft.Win32.Registry]::LocalMachine } else { [Microsoft.Win32.Registry]::CurrentUser }
    $key = $root.OpenSubKey($subKeyPath, $false)
    if (-not $key) {
        return @{ Raw = ''; Kind = [Microsoft.Win32.RegistryValueKind]::None }
    }
    try {
        $raw = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $kind = [Microsoft.Win32.RegistryValueKind]::None
        try {
            $kind = $key.GetValueKind('Path')
        } catch {
            $kind = [Microsoft.Win32.RegistryValueKind]::None
        }
        return @{ Raw = $raw; Kind = $kind }
    } finally {
        $key.Close()
    }
}

function Set-ExpandStringRegistryPath([string]$scope, [string]$newValue) {
    $subKeyPath = if ($scope -eq 'Machine') {
        'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    } else {
        'Environment'
    }
    $root = if ($scope -eq 'Machine') { [Microsoft.Win32.Registry]::LocalMachine } else { [Microsoft.Win32.Registry]::CurrentUser }
    $key = $null
    try {
        $key = $root.OpenSubKey($subKeyPath, $true)
    } catch {
        Write-Host "[ERROR] Insufficient permissions to modify $scope PATH in registry." -ForegroundColor Red
        return $false
    }
    if (-not $key) {
        Write-Host "[ERROR] Could not open registry key for scope '$scope' with write access." -ForegroundColor Red
        return $false
    }
    try {
        $existingKind = [Microsoft.Win32.RegistryValueKind]::None
        try {
            $existingKind = $key.GetValueKind('Path')
        } catch {}

        if ($existingKind -eq [Microsoft.Win32.RegistryValueKind]::String) {
            Write-Host "[REGISTRY FIX] Detected 'String' (REG_SZ) for $scope PATH. Repairing to 'ExpandString' (REG_EXPAND_SZ) to preserve %VAR% expansion (dotnet/runtime#1438 fix)." -ForegroundColor Yellow
        }
        $key.SetValue('Path', $newValue, [Microsoft.Win32.RegistryValueKind]::ExpandString)
        return $true
    } finally {
        $key.Close()
    }
}

# Helper to normalize paths for accurate comparison while preserving raw unexpanded %VAR% strings in storage
function Normalize-Dir([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return "" }
    return [Environment]::ExpandEnvironmentVariables($p.Trim()).TrimEnd('\')
}

# ---------------------------------------------------------
# 1. Privilege Check & Banner
# ---------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Clear-Host
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "   ULTIMATE WINDOWS PATH RESTORER & DEV ENVIRONMENT MANAGER" -ForegroundColor White
if ($isAdmin) {
    Write-Host "   Privilege Level: ADMINISTRATOR (User + System PATH Access)" -ForegroundColor Green
} else {
    Write-Host "   Privilege Level: STANDARD USER (User PATH + Fallback Access)" -ForegroundColor Yellow
}
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------
# 2. Automatic Timestamped Backup to Desktop
# ---------------------------------------------------------
$desktopDir = [Environment]::GetFolderPath('Desktop')
if (-not (Test-Path $desktopDir)) { $desktopDir = $env:USERPROFILE }
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$backupFile = Join-Path $desktopDir "PATH_Backup_$timestamp.txt"

$userInfo = Get-RawRegistryPathInfo 'User'
$sysInfo  = Get-RawRegistryPathInfo 'Machine'
$userPathRaw = $userInfo.Raw
$sysPathRaw  = $sysInfo.Raw

$backupContent = @(
    "Windows Environment PATH Backup - $timestamp"
    "=================================================================="
    "User PATH Registry Type:    $($userInfo.Kind)"
    "Machine PATH Registry Type: $($sysInfo.Kind)"
    "=================================================================="
    ""
    "[USER PATH - RAW]"
    $userPathRaw
    ""
    "[USER PATH - LIST]"
    ($userPathRaw -split ';' | Where-Object { $_ -ne '' })
    ""
    "=================================================================="
    ""
    "[SYSTEM PATH - RAW]"
    $sysPathRaw
    ""
    "[SYSTEM PATH - LIST]"
    ($sysPathRaw -split ';' | Where-Object { $_ -ne '' })
)
$backupContent | Out-File -FilePath $backupFile -Encoding UTF8
Write-Host "[BACKUP CREATED] Saved current PATH snapshot to:" -ForegroundColor Green
Write-Host "  $backupFile" -ForegroundColor DarkGray
if ($userInfo.Kind -eq [Microsoft.Win32.RegistryValueKind]::String) {
    Write-Host "[NOTICE] User PATH is currently stored as REG_SZ (String). It will be repaired to REG_EXPAND_SZ (ExpandString)." -ForegroundColor Yellow
}
Write-Host ""

$userEntries = New-Object System.Collections.Generic.List[string]
foreach ($item in ($userPathRaw -split ';')) {
    if (-not [string]::IsNullOrWhiteSpace($item)) { $userEntries.Add($item.Trim()) }
}

$sysEntries = New-Object System.Collections.Generic.List[string]
foreach ($item in ($sysPathRaw -split ';')) {
    if (-not [string]::IsNullOrWhiteSpace($item)) { $sysEntries.Add($item.Trim()) }
}

# ---------------------------------------------------------
# 3. Core Windows OS System32 Health Check
# ---------------------------------------------------------
$coreWinDirs = @(
    '%SystemRoot%\System32',
    '%SystemRoot%',
    '%SystemRoot%\System32\Wbem',
    '%SystemRoot%\System32\WindowsPowerShell\v1.0'
)

$allNormalized = @($userEntries + $sysEntries) | ForEach-Object { (Normalize-Dir $_).ToLower() }
$missingCore = @()
foreach ($core in $coreWinDirs) {
    $normCore = Normalize-Dir $core
    if ((Test-Path $normCore) -and ($allNormalized -notcontains $normCore.ToLower())) {
        $missingCore += $core
    }
}

if ($missingCore.Count -gt 0) {
    Write-Host "[CRITICAL WARNING] Core Windows OS paths are missing from PATH:" -ForegroundColor Red
    foreach ($mc in $missingCore) { Write-Host "  - $mc" -ForegroundColor Yellow }
    $fixCore = if ($isNonInteractive) { 'Y' } else { Read-Host "Restore missing core Windows paths now? (Y/N)" }
    if ($fixCore -match '^[Yy]') {
        if ($isAdmin) {
            foreach ($mc in $missingCore) { $sysEntries.Insert(0, $mc) }
            Set-ExpandStringRegistryPath 'Machine' ($sysEntries -join ';')
            Write-Host "[REPAIRED] Restored core Windows paths to System PATH (REG_EXPAND_SZ)." -ForegroundColor Green
        } else {
            foreach ($mc in $missingCore) { $userEntries.Insert(0, $mc) }
            Write-Host "[REPAIRED] Added core Windows paths to User PATH (run as Admin to move to System PATH)." -ForegroundColor Green
        }
    }
    Write-Host ""
}

# ---------------------------------------------------------
# 4. Dead / Non-Existent Entry Cleanup (QoL)
# ---------------------------------------------------------
$deadEntries = @()
foreach ($entry in $userEntries) {
    $expanded = Normalize-Dir $entry
    if ($expanded -and (-not (Test-Path $expanded))) {
        $deadEntries += $entry
    }
}

if ($deadEntries.Count -gt 0) {
    Write-Host "[CLEANUP] Found $($deadEntries.Count) broken/non-existent folder(s) in User PATH:" -ForegroundColor Yellow
    foreach ($de in $deadEntries) { Write-Host "  x $de" -ForegroundColor DarkYellow }
    $cleanChoice = if ($isNonInteractive) { if ($cleanDead) { 'Y' } else { 'N' } } else { Read-Host "Remove these dead entries to keep PATH clean? (Y/N)" }
    if ($cleanChoice -match '^[Yy]') {
        $userEntries = [System.Collections.Generic.List[string]]($userEntries | Where-Object { $deadEntries -notcontains $_ })
        Write-Host "[CLEANED] Removed dead entries." -ForegroundColor Green
    }
    Write-Host ""
}

# ---------------------------------------------------------
# 5. Deep Multi-Drive Developer Tool & Runtime Scan
# ---------------------------------------------------------
$toolSpecs = @(
    @{ Tool = 'Python';           Exe = 'python.exe';   Subdirs = @('Scripts') },
    @{ Tool = 'Node.js';          Exe = 'node.exe';     Subdirs = @() },
    @{ Tool = 'npm Global';       Exe = 'npm.cmd';      Subdirs = @() },
    @{ Tool = 'Git';              Exe = 'git.exe';      Subdirs = @() },
    @{ Tool = 'Java JDK';         Exe = 'javac.exe';    Subdirs = @() },
    @{ Tool = 'Go';               Exe = 'go.exe';       Subdirs = @() },
    @{ Tool = 'Rust (Cargo)';     Exe = 'cargo.exe';    Subdirs = @() },
    @{ Tool = 'PHP';              Exe = 'php.exe';      Subdirs = @() },
    @{ Tool = 'Composer';         Exe = 'composer.bat'; Subdirs = @() },
    @{ Tool = '.NET SDK';         Exe = 'dotnet.exe';   Subdirs = @() },
    @{ Tool = 'CMake';            Exe = 'cmake.exe';    Subdirs = @() },
    @{ Tool = 'MinGW / GCC';      Exe = 'gcc.exe';      Subdirs = @() },
    @{ Tool = 'C++ (MinGW G++)';  Exe = 'g++.exe';      Subdirs = @() },
    @{ Tool = 'MSVC C++ (cl.exe)';Exe = 'cl.exe';       Subdirs = @() },
    @{ Tool = 'LLVM / Clang++';   Exe = 'clang++.exe';  Subdirs = @() },
    @{ Tool = 'Ninja';            Exe = 'ninja.exe';    Subdirs = @() },
    @{ Tool = 'Emscripten';       Exe = 'emcc.bat';     Subdirs = @() },
    @{ Tool = 'FFmpeg';           Exe = 'ffmpeg.exe';   Subdirs = @() },
    @{ Tool = 'Docker';           Exe = 'docker.exe';   Subdirs = @() },
    @{ Tool = 'VS Code CLI';      Exe = 'code.cmd';     Subdirs = @() },
    @{ Tool = 'Android ADB';      Exe = 'adb.exe';      Subdirs = @() }
)

$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | Select-Object -ExpandProperty Root

$searchRoots = @(
    "$env:LocalAppData\Programs",
    "$env:LocalAppData\Android\Sdk\platform-tools",
    "$env:AppData\npm",
    "$env:UserProfile\.cargo\bin",
    "$env:UserProfile\go\bin",
    "$env:UserProfile\scoop\shims",
    "$env:UserProfile\.dotnet",
    "C:\ProgramData\chocolatey\bin",
    "C:\ProgramData\ComposerSetup\bin",
    "C:\Main Data\Apps",
    "C:\Main\Apps",
    "C:\msys64",
    "C:\mingw64",
    "C:\LLVM",
    "$env:ProgramFiles\LLVM",
    "${env:ProgramFiles(x86)}\LLVM",
    "$env:ProgramFiles",
    "${env:ProgramFiles(x86)}"
)

# Targeted Visual Studio / BuildTools search roots (avoids scanning millions of unrelated files)
$vsTargetGlobs = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64",
    "${env:ProgramFiles}\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\*\*\Common7\IDE\CommonExtensions\Microsoft\CMake\*",
    "${env:ProgramFiles}\Microsoft Visual Studio\*\*\Common7\IDE\CommonExtensions\Microsoft\CMake\*"
)
foreach ($pattern in $vsTargetGlobs) {
    Resolve-Path -Path $pattern -ErrorAction SilentlyContinue | ForEach-Object {
        $searchRoots += $_.Path
    }
}

foreach ($d in $drives) {
    if ($d -ne 'C:\') {
        $driveGlobs = @(
            "$d\Apps",
            "$d\Main Data\Apps",
            "$d\msys64",
            "$d\mingw64",
            "$d\LLVM",
            "$d\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64",
            "$d\Program Files (x86)\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64",
            "$d\Program Files\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64",
            "$d\Program Files (x86)\Microsoft Visual Studio\*\*\Common7\IDE\CommonExtensions\Microsoft\CMake\*",
            "$d\Program Files\Microsoft Visual Studio\*\*\Common7\IDE\CommonExtensions\Microsoft\CMake\*"
        )
        foreach ($dg in $driveGlobs) {
            Resolve-Path -Path $dg -ErrorAction SilentlyContinue | ForEach-Object { $searchRoots += $_.Path }
        }
    }
    $searchRoots += $d
}
$searchRoots = $searchRoots | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

Write-Host "[SCANNING] Searching drives for installed developer tools & C++ toolchains (10-25 seconds)..." -ForegroundColor Cyan

$exeNames = $toolSpecs.Exe
$discovered = @{}
foreach ($spec in $toolSpecs) {
    $discovered[$spec.Tool] = New-Object System.Collections.Generic.List[hashtable]
}

$ignoreRegex = 'WindowsApps|WinSxS|\$Recycle\.Bin|node_modules|\\venv\\|\\\.venv\\|\\env\\|site-packages|conda-meta|\\Temp\\|\\Cache\\'

foreach ($root in $searchRoots) {
    $depth = 3
    if ($root -match '^[A-Z]:\\$') {
        $depth = 2
    } elseif ($root -match 'Apps|msys64|mingw64') {
        $depth = 5
    } elseif ($root -match 'Microsoft Visual Studio.*(Hostx|CMake|Ninja)') {
        $depth = 2
    }

    $files = Get-ChildItem -Path $root -File -Depth $depth -ErrorAction SilentlyContinue | Where-Object { $exeNames -contains $_.Name }

    foreach ($f in $files) {
        if ($f.FullName -match $ignoreRegex) { continue }
        $dir = $f.DirectoryName.TrimEnd('\')
        $spec = $toolSpecs | Where-Object { $_.Exe -eq $f.Name } | Select-Object -First 1
        if (-not $spec) { continue }

        # Avoid duplicate directory entries for the same tool
        $alreadyFound = $discovered[$spec.Tool] | Where-Object { $_.Dir.ToLower() -eq $dir.ToLower() }
        if ($alreadyFound) { continue }

        # For MSVC cl.exe, prefer native 64-bit compiler (Hostx64\x64) over 32-bit Hostx86
        if ($spec.Exe -eq 'cl.exe' -and $f.FullName -match '\\bin\\Hostx86\\') {
            $x64Dir = $f.DirectoryName -replace 'Hostx86\\(x86|x64)', 'Hostx64\x64'
            if (Test-Path (Join-Path $x64Dir 'cl.exe')) { continue }
        }

        # Instant version detection via FileVersionInfo (safe, never hangs)
        $verInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($f.FullName)
        $ver = $verInfo.ProductVersion
        if ([string]::IsNullOrWhiteSpace($ver)) { $ver = $verInfo.FileVersion }
        if ([string]::IsNullOrWhiteSpace($ver)) {
            $parentDir = Split-Path $dir -Parent
            $leaf = Split-Path $dir -Leaf
            $ver = if ($leaf -match '^(bin|cmd|x64|x86)$') { "$(Split-Path $parentDir -Leaf)/$leaf" } else { $leaf }
        }

        $extraDirs = @()
        foreach ($sub in $spec.Subdirs) {
            $sp = Join-Path $dir $sub
            if (Test-Path $sp) { $extraDirs += $sp }
        }

        $discovered[$spec.Tool].Add(@{
            Dir       = $dir
            Version   = $ver.Trim()
            ExtraDirs = $extraDirs
        })
    }
}

# ---------------------------------------------------------
# 6. Interactive Version Selection & Prioritization
# ---------------------------------------------------------
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "   SCAN RESULTS & VERSION SELECTION" -ForegroundColor White
Write-Host "==================================================================" -ForegroundColor Cyan

$dirsToAdd      = New-Object System.Collections.Generic.List[string]
$dirsToPrepend  = New-Object System.Collections.Generic.List[string]
$currentAllNorm = @($userEntries + $sysEntries) | ForEach-Object { (Normalize-Dir $_).ToLower() }

foreach ($spec in $toolSpecs) {
    $toolName = $spec.Tool
    $matches = $discovered[$toolName]
    if ($matches.Count -eq 0) { continue }

    # Prefer Hostx64\x64 for MSVC if multiple hosts were discovered
    if ($toolName -eq 'MSVC C++ (cl.exe)') {
        $matches = [System.Collections.Generic.List[hashtable]]($matches | Sort-Object { if ($_.Dir -match 'Hostx64\\x64') { 0 } else { 1 } })
    }

    if ($matches.Count -eq 1) {
        $m = $matches[0]
        $inPath = $currentAllNorm -contains $m.Dir.ToLower()
        $alreadyQueued = ($dirsToAdd | ForEach-Object { (Normalize-Dir $_).ToLower() } -contains $m.Dir.ToLower()) -or
                         ($dirsToPrepend | ForEach-Object { (Normalize-Dir $_).ToLower() } -contains $m.Dir.ToLower())
        if ($inPath) {
            Write-Host "[OK]   $toolName ($($m.Version)) -> Already in PATH" -ForegroundColor DarkGray
        } elseif ($alreadyQueued) {
            Write-Host "[OK]   $toolName ($($m.Version)) -> Already queued for PATH" -ForegroundColor DarkGray
        } else {
            Write-Host "[ADD]  $toolName ($($m.Version)) -> $($m.Dir)" -ForegroundColor Green
            $dirsToAdd.Add($m.Dir)
        }
        foreach ($ex in $m.ExtraDirs) {
            if ($currentAllNorm -notcontains $ex.ToLower()) { $dirsToAdd.Add($ex) }
        }
    } else {
        Write-Host ""
        Write-Host "[MULTIPLE VERSIONS] $toolName ($($matches.Count) installations found):" -ForegroundColor Yellow
        for ($i = 0; $i -lt $matches.Count; $i++) {
            $m = $matches[$i]
            $status = if ($currentAllNorm -contains $m.Dir.ToLower()) { " [In PATH]" } else { " [Missing]" }
            Write-Host ("  [{0}] Version: {1,-22} | Path: {2}{3}" -f ($i + 1), $m.Version, $m.Dir, $status) -ForegroundColor White
        }
        if ($toolName -eq 'MSVC C++ (cl.exe)') {
            Write-Host "  * Note: cl.exe typically requires vcvars64.bat or VS Developer Command Prompt for INCLUDE/LIB." -ForegroundColor DarkCyan
        }
        Write-Host "  [A] Add ALL versions   |   [S] Skip $toolName" -ForegroundColor DarkCyan
        $choice = if ($isNonInteractive) { '1' } else { Read-Host "Select primary version number (1-$($matches.Count)), A, or S" }

        if ($choice -match '^[Aa]$') {
            foreach ($m in $matches) {
                $dirsToAdd.Add($m.Dir)
                foreach ($ex in $m.ExtraDirs) { $dirsToAdd.Add($ex) }
            }
            Write-Host "  -> Queued all $toolName versions." -ForegroundColor Green
        } elseif ($choice -match '^\d+$') {
            $idx = [int]$choice - 1
            if ($idx -ge 0 -and $idx -lt $matches.Count) {
                $selected = $matches[$idx]
                $prio = if ($isNonInteractive) { 'N' } else { Read-Host "  Place this version at the TOP of PATH so it takes priority over others? (Y/N)" }
                if ($prio -match '^[Yy]') {
                    foreach ($ex in $selected.ExtraDirs) { $dirsToPrepend.Add($ex) }
                    $dirsToPrepend.Add($selected.Dir)
                    Write-Host "  -> Prioritized $($selected.Version) at the front of PATH." -ForegroundColor Cyan
                } else {
                    $dirsToAdd.Add($selected.Dir)
                    foreach ($ex in $selected.ExtraDirs) { $dirsToAdd.Add($ex) }
                    Write-Host "  -> Queued $($selected.Version)." -ForegroundColor Green
                }
            } else {
                Write-Host "  -> Invalid number, skipped $toolName." -ForegroundColor DarkYellow
            }
        } else {
            Write-Host "  -> Skipped $toolName." -ForegroundColor DarkGray
        }
    }
}

# ---------------------------------------------------------
# 7. Custom Folder Prompt (QoL)
# ---------------------------------------------------------
Write-Host ""
$customFolder = if ($isNonInteractive) { '' } else { Read-Host "Optional: Paste any extra custom folder path to add (or press Enter to finish)" }
if (-not [string]::IsNullOrWhiteSpace($customFolder)) {
    $cleanCustom = $customFolder.Trim('"').Trim().TrimEnd('\')
    if (Test-Path $cleanCustom) {
        $dirsToAdd.Add($cleanCustom)
        Write-Host "[QUEUED CUSTOM] $cleanCustom" -ForegroundColor Green
    } else {
        Write-Host "[INVALID PATH] Folder does not exist: $cleanCustom" -ForegroundColor Red
    }
}

# ---------------------------------------------------------
# 8. Deduplicate, Apply Changes (REG_EXPAND_SZ) & Broadcast
# ---------------------------------------------------------
$finalList = New-Object System.Collections.Generic.List[string]
$seenNorm  = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

# 1st: Prioritized versions go to the very front
foreach ($p in $dirsToPrepend) {
    $norm = Normalize-Dir $p
    if ($norm -and $seenNorm.Add($norm)) { $finalList.Add($p.TrimEnd('\')) }
}

# 2nd: Existing User PATH entries (preserving order, keeping original raw %VAR% formatting)
foreach ($u in $userEntries) {
    $norm = Normalize-Dir $u
    if ($norm -and $seenNorm.Add($norm)) { $finalList.Add($u.TrimEnd('\')) }
}

# 3rd: Newly restored tool directories
$sysNormSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
foreach ($s in $sysEntries) {
    $sn = Normalize-Dir $s
    if ($sn) { [void]$sysNormSet.Add($sn) }
}

foreach ($a in $dirsToAdd) {
    $norm = Normalize-Dir $a
    if ($norm -and (-not $sysNormSet.Contains($norm)) -and $seenNorm.Add($norm)) {
        $finalList.Add($a.TrimEnd('\'))
    }
}

$newUserPath = $finalList -join ';'
Set-ExpandStringRegistryPath 'User' $newUserPath

# Notify Windows Explorer & active desktop apps of environment update
Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
$result = [UIntPtr]::Zero
[Win32.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$result) | Out-Null

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "   COMPLETE! User PATH updated cleanly ($($finalList.Count) total entries as REG_EXPAND_SZ)." -ForegroundColor White
Write-Host "   Backup saved at: $backupFile" -ForegroundColor DarkGray
Write-Host "   Open a NEW terminal window to verify your restored tools." -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Green
