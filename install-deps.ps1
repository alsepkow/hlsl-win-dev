#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs all HLSL Developer Environment dependencies via winget.

.DESCRIPTION
    Uses winget to install every prerequisite for building LLVM (with HLSL
    support) and DirectXShaderCompiler on Windows.  All packages are installed
    with --scope machine so they are available system-wide.

    Must be run from an elevated (Administrator) PowerShell session.

    After installation completes the script refreshes PATH from the registry
    so that newly-installed tools (e.g. Python) are available immediately for
    post-install steps such as pip-installing pyyaml.  Other terminal windows
    may still need to be restarted for PATH changes to take effect.

.EXAMPLE
    # Run from an elevated PowerShell:
    .\install-deps.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────────────────────────────────────
# Verify winget is available
# ─────────────────────────────────────────────────────────────────────────────
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    throw "winget is not available. Install App Installer from the Microsoft Store or update Windows."
}

$wingetVer = (& winget --version 2>&1)
Write-Host "Using winget $wingetVer" -ForegroundColor Cyan

# ─────────────────────────────────────────────────────────────────────────────
# Package list
# ─────────────────────────────────────────────────────────────────────────────
# Visual Studio workloads and individual components to install via setup.exe modify.
$VSComponents = @(
    "Microsoft.VisualStudio.Workload.NativeDesktop",              # Desktop Development with C++ (includes MSVC)
    "Microsoft.VisualStudio.Component.VC.CMake.Project",          # C++ CMake tools for Windows (CMake, Ninja)
    "Microsoft.VisualStudio.Component.VC.Llvm.Clang",             # C++ Clang tools for Windows
    "Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset",      # MSBuild support for LLVM (clang-cl) toolset
    "Microsoft.VisualStudio.Component.Windows11SDK.26100",         # Windows 11 SDK (10.0.26100)
    "Component.Microsoft.Windows.DriverKit"                        # Windows Driver Kit (includes TAEF)
)

$Packages = @(
    @{ Id = "Microsoft.Git";                        Name = "Git" },
    @{ Id = "KhronosGroup.VulkanSDK";               Name = "Vulkan SDK" },
    @{ Id = "Python.Python.3.14";                    Name = "Python 3.14" },
    @{ Id = "Mozilla.sccache";                       Name = "sccache" }
)

# ─────────────────────────────────────────────────────────────────────────────
# Install each package
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Installing HLSL Dev Dependencies ===" -ForegroundColor Cyan

$Failed = @()

# ─────────────────────────────────────────────────────────────────────────────
# Visual Studio 2026 Community (with required workloads and components)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n--- Visual Studio 2026 Community (with workloads) ---" -ForegroundColor Cyan

# Step 1: Ensure VS Community is installed (no component overrides — let
#          winget handle the base install cleanly).
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsSetup = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"

$vsInstallPath = $null
if (Test-Path $vswhere) {
    $vsInstallPath = & $vswhere -latest -products * -property installationPath
}

if (-not $vsInstallPath) {
    Write-Host "  Installing Visual Studio 2026 Community..." -ForegroundColor DarkGray
    & winget install --id Microsoft.VisualStudio.Community --scope machine `
        --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAILED] Visual Studio 2026 Community — winget exited with code $LASTEXITCODE" -ForegroundColor Red
        $Failed += "Visual Studio 2026 Community"
    }

    # Re-detect after install
    if (Test-Path $vswhere) {
        $vsInstallPath = & $vswhere -latest -products * -property installationPath
    }
}

# Step 2: Add required workloads and components via the VS Installer.
if ($vsInstallPath -and (Test-Path $vsSetup)) {
    Write-Host "  Adding components to $vsInstallPath ..." -ForegroundColor DarkGray
    Write-Host "  Components: $($VSComponents -join ', ')" -ForegroundColor DarkGray

    $modifyArgs = @("modify", "--installPath", "`"$vsInstallPath`"")
    foreach ($comp in $VSComponents) {
        $modifyArgs += "--add"
        $modifyArgs += $comp
    }
    $modifyArgs += "--passive"
    $modifyArgStr = $modifyArgs -join " "

    Write-Host "  $vsSetup $modifyArgStr" -ForegroundColor DarkGray
    $proc = Start-Process -FilePath $vsSetup -ArgumentList $modifyArgStr -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        Write-Host "  [FAILED] VS Installer modify exited with code $($proc.ExitCode)" -ForegroundColor Red
        $Failed += "Visual Studio 2026 Community (components)"
    }
    else {
        Write-Host "  [OK] Visual Studio 2026 Community" -ForegroundColor Green
    }
}
elseif (-not $vsInstallPath) {
    Write-Host "  [FAILED] Visual Studio not found after install attempt" -ForegroundColor Red
    $Failed += "Visual Studio 2026 Community"
}
else {
    Write-Host "  [FAILED] VS Installer (setup.exe) not found — cannot add components" -ForegroundColor Red
    $Failed += "Visual Studio 2026 Community (components)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Remaining packages (simple winget installs)
# ─────────────────────────────────────────────────────────────────────────────
foreach ($pkg in $Packages) {
    Write-Host "`n--- $($pkg.Name) ($($pkg.Id)) ---" -ForegroundColor Cyan

    # Check if the package is already installed before attempting install.
    # Some installers (e.g. Vulkan SDK) return non-zero when the same version
    # is already present, which winget reports as a failure.
    & winget list --id $pkg.Id --exact --accept-source-agreements 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $($pkg.Name) (already installed)" -ForegroundColor Green
        continue
    }

    & winget install --id $pkg.Id --scope machine --accept-source-agreements --accept-package-agreements

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAILED] $($pkg.Name) — winget exited with code $LASTEXITCODE" -ForegroundColor Red
        $Failed += $pkg.Name
    }
    else {
        Write-Host "  [OK] $($pkg.Name)" -ForegroundColor Green
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Refresh PATH from the registry so newly-installed tools are visible
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`nRefreshing PATH from registry..." -ForegroundColor DarkGray

$MachinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$UserPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path    = "$MachinePath;$UserPath"

# ─────────────────────────────────────────────────────────────────────────────
# Post-install: pyyaml (needed by LLVM LIT tests)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n--- pyyaml (pip) ---" -ForegroundColor Cyan

$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    & python -m pip install pyyaml
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAILED] pyyaml — pip exited with code $LASTEXITCODE" -ForegroundColor Red
        $Failed += "pyyaml"
    }
    else {
        Write-Host "  [OK] pyyaml" -ForegroundColor Green
    }
}
else {
    Write-Host "  [SKIPPED] Python not yet on PATH — restart your terminal, then run: pip install pyyaml" -ForegroundColor Yellow
}

# ─────────────────────────────────────────────────────────────────────────────
# Post-install: Graphics Tools optional Windows feature
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n--- Graphics Tools (Windows optional feature) ---" -ForegroundColor Cyan

$d3d12LayersDll = Join-Path $env:SystemRoot "System32\d3d12SDKLayers.dll"
if (Test-Path $d3d12LayersDll) {
    Write-Host "  [OK] Graphics Tools already installed" -ForegroundColor Green
}
else {
    & dism /Online /Add-Capability /CapabilityName:Tools.Graphics.DirectX~~~~0.0.1.0 /NoRestart
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAILED] Graphics Tools — dism exited with code $LASTEXITCODE" -ForegroundColor Red
        $Failed += "Graphics Tools"
    }
    else {
        Write-Host "  [OK] Graphics Tools" -ForegroundColor Green
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Summary ===" -ForegroundColor Cyan

if ($Failed.Count -eq 0) {
    Write-Host "All dependencies installed successfully." -ForegroundColor Green
}
else {
    Write-Host "The following items failed to install:" -ForegroundColor Red
    foreach ($name in $Failed) {
        Write-Host "  - $name" -ForegroundColor Red
    }
}

Write-Host @"

Next steps:
  1. Open a new terminal so PATH entries take effect in other shells.
  2. Run .\hlsl-dev.ps1 check-prereqs to verify everything is ready.

"@ -ForegroundColor White

if ($Failed.Count -gt 0) {
    exit 1
}
