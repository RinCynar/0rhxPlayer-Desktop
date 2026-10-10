param(
    [string]$Version = "1.1.0",
    [string]$BuildDir = "build",
    [string]$DistDir = "dist",
    [string]$QtBinDir = "",
    [string]$IsccPath = ""
)

$ErrorActionPreference = "Continue"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

Write-Host "=== Packaging 0rhxPlayer v$Version ===" -ForegroundColor Cyan

# 1. Locate ISCC (Inno Setup Compiler)
if (-not $IsccPath) {
    $candidates = @(
        "C:\InnoSetup\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 7\ISCC.exe",
        "C:\Program Files\Inno Setup 7\ISCC.exe",
        "C:\ProgramData\chocolatey\bin\iscc.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $IsccPath = $c; break }
    }
    if (-not $IsccPath) {
        $isccCmd = Get-Command iscc -ErrorAction SilentlyContinue
        if ($isccCmd) {
            $IsccPath = if ($isccCmd.Path) { $isccCmd.Path } else { $isccCmd.Source }
        }
    }
    if (-not $IsccPath -or -not (Test-Path $IsccPath)) {
        $foundIscc = Get-ChildItem -Path "C:\Program Files*", "C:\ProgramData\chocolatey" -Filter "ISCC.exe" -Recurse -Depth 4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($foundIscc) { $IsccPath = $foundIscc.FullName }
    }
}
Write-Host "Using Inno Setup compiler: $IsccPath" -ForegroundColor Green
if (-not $IsccPath -or -not (Test-Path $IsccPath)) {
    throw "Inno Setup compiler (ISCC.exe) not found!"
}

# 2. Prepare staging directory
$StageDir = Join-Path $RootDir "$DistDir\0rhxPlayer"
$DistFullPath = Join-Path $RootDir $DistDir
if (Test-Path $StageDir) {
    Remove-Item -Recurse -Force $StageDir
}
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null
New-Item -ItemType Directory -Force -Path $DistFullPath | Out-Null

# 3. Copy executable
$ExeSource = Join-Path $RootDir "$BuildDir\0rhxPlayer.exe"
if (-not (Test-Path $ExeSource)) {
    throw "Target binary $ExeSource not found! Please build the project first."
}
Copy-Item $ExeSource (Join-Path $StageDir "0rhxPlayer.exe") -Force

# 4. Copy BASS libraries
$BassBinDir = Join-Path $RootDir "libs\bass\bin"
if (Test-Path $BassBinDir) {
    Copy-Item "$BassBinDir\*.dll" $StageDir -Force
    Write-Host "Copied BASS runtime DLLs." -ForegroundColor Green
}

# 5. Copy Assets and Translations
Copy-Item -Recurse (Join-Path $RootDir "assets") (Join-Path $StageDir "assets") -Force
New-Item -ItemType Directory -Force -Path (Join-Path $StageDir "translations") | Out-Null
Copy-Item (Join-Path $RootDir "translations\*.qm") (Join-Path $StageDir "translations") -Force -ErrorAction SilentlyContinue

# 6. Run windeployqt
$WindeployqtCmd = ""
$qtDirs = @(
    $QtBinDir,
    (if ($env:QT_DIR) { Join-Path $env:QT_DIR "bin" } else { $null }),
    (if ($env:QT_ROOT) { Join-Path $env:QT_ROOT "bin" } else { $null }),
    (if ($env:QT_ROOT_DIR) { Join-Path $env:QT_ROOT_DIR "bin" } else { $null }),
    (if ($env:Qt6_DIR) { (Resolve-Path "$env:Qt6_DIR\..\..\..\bin" -ErrorAction SilentlyContinue).Path } else { $null }),
    (if ($env:CMAKE_PREFIX_PATH) { Join-Path $env:CMAKE_PREFIX_PATH "bin" } else { $null })
)
foreach ($qd in $qtDirs) {
    if ($qd -and (Test-Path (Join-Path $qd "windeployqt.exe"))) {
        $WindeployqtCmd = Join-Path $qd "windeployqt.exe"
        break
    }
}
if (-not $WindeployqtCmd) {
    $qtCmd = Get-Command windeployqt -ErrorAction SilentlyContinue
    if ($qtCmd) {
        $WindeployqtCmd = if ($qtCmd.Path) { $qtCmd.Path } else { $qtCmd.Source }
    }
}
if (-not $WindeployqtCmd -or -not (Test-Path $WindeployqtCmd)) {
    $qtWildcards = @(
        "C:\Qt\*\mingw_64\bin\windeployqt.exe",
        "D:\a\*\Qt\*\mingw_64\bin\windeployqt.exe",
        "C:\hostedtoolcache\windows\Qt\*\mingw_64\bin\windeployqt.exe",
        "C:\Users\RinCynar\Qt\6.11.2\mingw_64\bin\windeployqt.exe"
    )
    foreach ($w in $qtWildcards) {
        $matched = Get-Item $w -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($matched -and (Test-Path $matched.FullName)) {
            $WindeployqtCmd = $matched.FullName
            break
        }
    }
}
if (-not $WindeployqtCmd -or -not (Test-Path $WindeployqtCmd)) {
    $foundQt = Get-ChildItem -Path "C:\", "D:\" -Filter "windeployqt.exe" -Recurse -Depth 5 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($foundQt) { $WindeployqtCmd = $foundQt.FullName }
}

Write-Host "Using windeployqt: $WindeployqtCmd" -ForegroundColor Green
if (-not $WindeployqtCmd -or -not (Test-Path $WindeployqtCmd)) {
    throw "windeployqt.exe not found!"
}

Write-Host "Running windeployqt ($WindeployqtCmd) on $StageDir\0rhxPlayer.exe ..." -ForegroundColor Cyan
& $WindeployqtCmd --qmldir "$RootDir\src\qml" --compiler-runtime "$StageDir\0rhxPlayer.exe" 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Warning "windeployqt completed with exit code: $LASTEXITCODE"
}

# 7. Create Portable Zip
$ZipName = "0rhxPlayer-v$Version-windows-x64-portable.zip"
$ZipPath = Join-Path $DistFullPath $ZipName
if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Write-Host "Creating portable marker in staging directory..." -ForegroundColor Cyan
New-Item -ItemType File -Path (Join-Path $StageDir "portable.dat") -Force | Out-Null
Write-Host "Compressing portable zip: $ZipPath ..." -ForegroundColor Cyan
Compress-Archive -Path "$StageDir\*" -DestinationPath $ZipPath -Force
Write-Host "Created $ZipName (Size: $((Get-Item $ZipPath).Length) bytes)" -ForegroundColor Green
Remove-Item -Force (Join-Path $StageDir "portable.dat") -ErrorAction SilentlyContinue

# 8. Compile Inno Setup Installer
$SetupName = "0rhxPlayer-v$Version-windows-x64-setup"
Write-Host "Compiling Inno Setup installer..." -ForegroundColor Cyan
& $IsccPath "-dSourceDir=$StageDir" "-o$DistFullPath" "-f$SetupName" "$RootDir\installer\setup.iss" 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed with exit code $LASTEXITCODE"
}

$SetupExePath = Join-Path $DistFullPath "$SetupName.exe"
if (Test-Path $SetupExePath) {
    Write-Host "Created $SetupName.exe (Size: $((Get-Item $SetupExePath).Length) bytes)" -ForegroundColor Green
}

Write-Host "=== Dual Release Packaging Complete ===" -ForegroundColor Green
