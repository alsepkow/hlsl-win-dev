# HLSL Developer Environment (Windows)

Windows equivalent of [hlsl-dev](https://github.com/Icohedron/hlsl-dev) -- a self-contained developer environment for working on LLVM's HLSL features and Microsoft's DirectXShaderCompiler (DXC).

Uses PowerShell and Visual Studio instead of Nix.

## Prerequisites

- **PowerShell 7** (`winget install Microsoft.PowerShell`) -- the scripts require PowerShell 7 and are not compatible with Windows PowerShell 5.1
  - Your execution policy must allow running scripts. If it doesn't, set it with:
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```
- **Visual Studio 2026** (or 2022/2019) with workloads:
  - Desktop Development with C++
- **Windows SDK** >= 10.0.26100.0
- **Windows Driver Kit (WDK)** -- same version as SDK (for TAEF tests)
- **Python 3.x** (`pip install pyyaml` for LIT tests)
- **Git**
- **CMake** >= 3.17.2 (bundled with VS works)
- **Ninja** (`winget install Ninja-build.Ninja`)

Optional:
- **sccache** (`winget install Mozilla.sccache`) -- compiler caching for faster rebuilds

You can install all of the above automatically by running `.\install-deps.ps1` in an **administrator** PowerShell.

Run `.\hlsl-dev.ps1 check-prereqs` to verify your setup.

## Quickstart

```powershell
# Open a Visual Studio Developer PowerShell (for Ninja builds)
# or a regular PowerShell (for VS generator builds)

.\hlsl-dev.ps1 check-prereqs
.\hlsl-dev.ps1 setup

# Build DXC
.\hlsl-dev.ps1 configure-dxc
.\hlsl-dev.ps1 build-dxc

# Build LLVM with HLSL support
.\hlsl-dev.ps1 configure-llvm
.\hlsl-dev.ps1 build-llvm
```

## Commands

| Command | Description |
|---------|-------------|
| `check-prereqs` | Verify required tools are installed |
| `setup` | Initialize submodules (shallow clone, depth 2) |
| `configure-llvm` | Configure LLVM with CMake |
| `build-llvm` | Build LLVM (auto-configures if needed) |
| `configure-dxc` | Configure DXC with CMake |
| `build-dxc` | Build DXC (auto-configures if needed) |
| `fetch-history` | Fetch full git history for a submodule |
| `truncate-history` | Truncate submodule history to depth 2 |
| `update-submodules` | Update all submodules to latest upstream |

## Parameters

| Parameter | Values | Default |
|-----------|--------|---------|
| `-BuildType` | `Debug`, `Release`, `RelWithDebInfo`, `MinSizeRel` | `RelWithDebInfo` |
| `-Generator` | `Ninja`, `VS2026`, `VS2022`, `VS2019` | `Ninja` |
| `-Target` | Any CMake target (e.g., `clang`, `dxc`, `check-all`, `check-hlsl`) | (all) |
| `-Repo` | Submodule name (for `fetch-history`/`truncate-history`) | |

## Examples

```powershell
# Debug build of DXC with Ninja
.\hlsl-dev.ps1 configure-dxc -BuildType Debug
.\hlsl-dev.ps1 build-dxc -BuildType Debug

# Generate a Visual Studio solution for DXC
.\hlsl-dev.ps1 configure-dxc -Generator VS2026
# Then open DirectXShaderCompiler\build\LLVM.sln

# Build only the dxc target
.\hlsl-dev.ps1 build-dxc -Target dxc

# Run HLSL tests in LLVM
.\hlsl-dev.ps1 build-llvm -Target check-hlsl

# Run all DXC tests
.\hlsl-dev.ps1 build-dxc -Target check-all

# Fetch full history for a submodule (for rebasing, PRs, etc.)
.\hlsl-dev.ps1 fetch-history -Repo llvm-project

# Truncate it back to save disk space
.\hlsl-dev.ps1 truncate-history -Repo llvm-project
```

## Ninja vs Visual Studio Generator

**Ninja** (default): Faster builds, single-config. Requires running from a Visual Studio Developer PowerShell so MSVC is on PATH.

**VS2026/VS2022/VS2019**: Generates an `LLVM.sln` solution file. Multi-config (switch Debug/Release in IDE). Best for debugging in Visual Studio.

## Differences from the Nix Version

| Nix (Linux) | Windows |
|-------------|---------|
| Clang + LLD toolchain | MSVC (via Visual Studio) |
| `nix develop` manages all deps | `.\install-deps.ps1` or manual install |
| `mask` task runner | `.\hlsl-dev.ps1` PowerShell script |
| sccache always available | sccache optional (auto-detected) |
| `-DLLVM_ENABLE_LLD=ON` | Not set (MSVC uses its own linker) |
| vkd3d-proton, vulkan-loader | Not included (Windows has native D3D12) |
