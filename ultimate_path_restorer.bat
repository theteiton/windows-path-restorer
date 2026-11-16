@echo off
setlocal
title Ultimate Windows PATH Restorer & Dev Environment Manager
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "$raw = Get-Content -LiteralPath '%~f0' -Raw -Encoding UTF8; $marker = '#__PS_' + 'START__'; $ps = $raw.Substring($raw.LastIndexOf($marker)); Invoke-Expression $ps"
echo.
pause
exit /b
#__PS_START__

$ErrorActionPreference = 'SilentlyContinue'

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

$userPathRaw = [Environment]::GetEnvironmentVariable('Path', 'User')
$sysPathRaw  = [Environment]::GetEnvironmentVariable('Path', 'Machine')

$backupContent = @(
    "Windows Environment PATH Backup - $timestamp"
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
Write-Host ""

# Helper to normalize paths for accurate comparison
function Normalize-Dir([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return "" }
    return [Environment]::ExpandEnvironmentVariables($p.Trim()).TrimEnd('\')
}

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
    "$env:SystemRoot\System32",
    "$env:SystemRoot",
    "$env:SystemRoot\System32\Wbem",
    "$env:SystemRoot\System32\WindowsPowerShell\v1.0"
)

$allNormalized = @($userEntries + $sysEntries) | ForEach-Object { (Normalize-Dir $_).ToLower() }
$missingCore = @()
foreach ($core in $coreWinDirs) {
    if ((Test-Path $core) -and ($allNormalized -notcontains $core.ToLower())) {
        $missingCore += $core
    }
}

if ($missingCore.Count -gt 0) {
    Write-Host "[CRITICAL WARNING] Core Windows OS paths are missing from PATH:" -ForegroundColor Red
    foreach ($mc in $missingCore) { Write-Host "  - $mc" -ForegroundColor Yellow }
    $fixCore = Read-Host "Restore missing core Windows paths now? (Y/N)"
    if ($fixCore -match '^[Yy]') {
        if ($isAdmin) {
            foreach ($mc in $missingCore) { $sysEntries.Insert(0, $mc) }
            [Environment]::SetEnvironmentVariable('Path', ($sysEntries -join ';'), 'Machine')
            Write-Host "[REPAIRED] Restored core Windows paths to System PATH." -ForegroundColor Green
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
    $cleanChoice = Read-Host "Remove these dead entries to keep PATH clean? (Y/N)"
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
    @{ Tool = 'Python';       Exe = 'python.exe';   Subdirs = @('Scripts') },
    @{ Tool = 'Node.js';      Exe = 'node.exe';     Subdirs = @() },
    @{ Tool = 'npm Global';   Exe = 'npm.cmd';      Subdirs = @() },
    @{ Tool = 'Git';          Exe = 'git.exe';      Subdirs = @() },
    @{ Tool = 'Java JDK';     Exe = 'javac.exe';    Subdirs = @() },
    @{ Tool = 'Go';           Exe = 'go.exe';       Subdirs = @() },
    @{ Tool = 'Rust (Cargo)'; Exe = 'cargo.exe';    Subdirs = @() },
    @{ Tool = 'PHP';          Exe = 'php.exe';      Subdirs = @() },
    @{ Tool = 'Composer';     Exe = 'composer.bat'; Subdirs = @() },
    @{ Tool = '.NET SDK';     Exe = 'dotnet.exe';   Subdirs = @() },
    @{ Tool = 'CMake';        Exe = 'cmake.exe';    Subdirs = @() },
    @{ Tool = 'MinGW / GCC';  Exe = 'gcc.exe';      Subdirs = @() },
    @{ Tool = 'FFmpeg';       Exe = 'ffmpeg.exe';   Subdirs = @() },
    @{ Tool = 'Docker';       Exe = 'docker.exe';   Subdirs = @() },
    @{ Tool = 'VS Code CLI';  Exe = 'code.cmd';     Subdirs = @() },
    @{ Tool = 'Android ADB';  Exe = 'adb.exe';      Subdirs = @() }
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
    $env:ProgramFiles,
    ${env:ProgramFiles(x86)}
)
foreach ($d in $drives) { $searchRoots += $d }
$searchRoots = $searchRoots | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

Write-Host "[SCANNING] Searching drives for installed developer tools (10-25 seconds)..." -ForegroundColor Cyan

$exeNames = $toolSpecs.Exe
$discovered = @{}
foreach ($spec in $toolSpecs) {
    $discovered[$spec.Tool] = New-Object System.Collections.Generic.List[hashtable]
}

$ignoreRegex = 'WindowsApps|WinSxS|\$Recycle\.Bin|node_modules|\\venv\\|\\\.venv\\|\\env\\|site-packages|conda-meta|\\Temp\\|\\Cache\\'

foreach ($root in $searchRoots) {
    $depth = if ($root -match '^[A-Z]:\\$') { 2 } else { 3 }
    $files = Get-ChildItem -Path $root -File -Depth $depth -ErrorAction SilentlyContinue | Where-Object { $exeNames -contains $_.Name }

    foreach ($f in $files) {
        if ($f.FullName -match $ignoreRegex) { continue }
        $dir = $f.DirectoryName.TrimEnd('\')
        $spec = $toolSpecs | Where-Object { $_.Exe -eq $f.Name } | Select-Object -First 1
        if (-not $spec) { continue }

        # Avoid duplicate directory entries for the same tool
        $alreadyFound = $discovered[$spec.Tool] | Where-Object { $_.Dir.ToLower() -eq $dir.ToLower() }
        if ($alreadyFound) { continue }

        # Instant version detection via FileVersionInfo (safe, never hangs)
        $verInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($f.FullName)
        $ver = $verInfo.ProductVersion
        if ([string]::IsNullOrWhiteSpace($ver)) { $ver = $verInfo.FileVersion }
        if ([string]::IsNullOrWhiteSpace($ver)) { $ver = "CLI / Folder: $(Split-Path $dir -Leaf)" }

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

    if ($matches.Count -eq 1) {
        $m = $matches[0]
        $inPath = $currentAllNorm -contains $m.Dir.ToLower()
        if ($inPath) {
            Write-Host "[OK]   $toolName ($($m.Version)) -> Already in PATH" -ForegroundColor DarkGray
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
        Write-Host "  [A] Add ALL versions   |   [S] Skip $toolName" -ForegroundColor DarkCyan
        $choice = Read-Host "Select primary version number (1-$($matches.Count)), A, or S"

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
                $prio = Read-Host "  Place this version at the TOP of PATH so it takes priority over others? (Y/N)"
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
$customFolder = Read-Host "Optional: Paste any extra custom folder path to add (or press Enter to finish)"
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
# 8. Deduplicate, Apply Changes & Broadcast WM_SETTINGCHANGE
# ---------------------------------------------------------
$finalList = New-Object System.Collections.Generic.List[string]
$seenNorm  = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

# 1st: Prioritized versions go to the very front
foreach ($p in $dirsToPrepend) {
    $norm = Normalize-Dir $p
    if ($norm -and $seenNorm.Add($norm)) { $finalList.Add($p.TrimEnd('\')) }
}

# 2nd: Existing User PATH entries (preserving order, removing duplicates)
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
[Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')

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
Write-Host "   COMPLETE! User PATH updated cleanly ($($finalList.Count) total entries)." -ForegroundColor White
Write-Host "   Backup saved at: $backupFile" -ForegroundColor DarkGray
Write-Host "   Open a NEW terminal window to verify your restored tools." -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Green