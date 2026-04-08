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
# Visual Studio workloads and individual components to install via --override.
# These are passed directly to the VS Installer (vs_community.exe) as --add flags.
$VSComponents = @(
    "Microsoft.VisualStudio.Workload.NativeDesktop",              # Desktop Development with C++ (includes MSVC, CMake, etc.)
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

$vsOverride = ($VSComponents | ForEach-Object { "--add $_" }) -join " "
$vsOverride += " --passive"

Write-Host "  Components: $($VSComponents -join ', ')" -ForegroundColor DarkGray
Write-Host "  winget install --id Microsoft.VisualStudio.Community --scope machine --override `"$vsOverride`"" -ForegroundColor DarkGray

& winget install --id Microsoft.VisualStudio.Community --scope machine `
    --accept-source-agreements --accept-package-agreements `
    --override $vsOverride
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [FAILED] Visual Studio 2026 Community — winget exited with code $LASTEXITCODE" -ForegroundColor Red
    $Failed += "Visual Studio 2026 Community"
}
else {
    Write-Host "  [OK] Visual Studio 2026 Community" -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────────────────────
# Remaining packages (simple winget installs)
# ─────────────────────────────────────────────────────────────────────────────
foreach ($pkg in $Packages) {
    Write-Host "`n--- $($pkg.Name) ($($pkg.Id)) ---" -ForegroundColor Cyan

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
