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
    if (Get-Command iscc -ErrorAction SilentlyContinue) {
        $IsccPath = (Get-Command iscc).Source
    } else {
        $candidates = @(
            "C:\Program Files\Inno Setup 7\ISCC.exe",
            "C:\Program Files (x86)\Inno Setup 7\ISCC.exe",
            "C:\Program Files\Inno Setup 6\ISCC.exe",
            "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
            "C:\ProgramData\chocolatey\bin\iscc.exe"
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) { $IsccPath = $c; break }
        }
        if (-not $IsccPath) {
            $searched = Get-ChildItem -Path "C:\Program Files*", "C:\ProgramData\chocolatey" -Recurse -Filter "ISCC.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($searched) {
                $IsccPath = $searched.FullName
            } else {
                $IsccPath = "iscc"
            }
        }
    }
}
Write-Host "Using Inno Setup compiler: $IsccPath" -ForegroundColor Green

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
$WindeployqtCmd = "windeployqt"
if ($QtBinDir -and (Test-Path (Join-Path $QtBinDir "windeployqt.exe"))) {
    $WindeployqtCmd = Join-Path $QtBinDir "windeployqt.exe"
} elseif (Get-Command windeployqt -ErrorAction SilentlyContinue) {
    $WindeployqtCmd = "windeployqt"
} elseif (Test-Path "C:\Users\RinCynar\Qt\6.11.2\mingw_64\bin\windeployqt.exe") {
    $WindeployqtCmd = "C:\Users\RinCynar\Qt\6.11.2\mingw_64\bin\windeployqt.exe"
}

Write-Host "Running windeployqt on $StageDir\0rhxPlayer.exe ..." -ForegroundColor Cyan
& $WindeployqtCmd --qmldir "$RootDir\src\qml" --compiler-runtime "$StageDir\0rhxPlayer.exe"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "windeployqt completed with exit code: $LASTEXITCODE"
}

# 7. Create Portable Zip
$ZipName = "0rhxPlayer-v$Version-windows-x64-portable.zip"
$ZipPath = Join-Path $DistFullPath $ZipName
if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Write-Host "Compressing portable zip: $ZipPath ..." -ForegroundColor Cyan
Compress-Archive -Path "$StageDir\*" -DestinationPath $ZipPath -Force
Write-Host "Created $ZipName (Size: $((Get-Item $ZipPath).Length) bytes)" -ForegroundColor Green

# 8. Compile Inno Setup Installer
$SetupName = "0rhxPlayer-v$Version-windows-x64-setup"
Write-Host "Compiling Inno Setup installer..." -ForegroundColor Cyan
& $IsccPath "-dSourceDir=$StageDir" "-o$DistFullPath" "-f$SetupName" "$RootDir\installer\setup.iss"
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed with exit code $LASTEXITCODE"
}

$SetupExePath = Join-Path $DistFullPath "$SetupName.exe"
if (Test-Path $SetupExePath) {
    Write-Host "Created $SetupName.exe (Size: $((Get-Item $SetupExePath).Length) bytes)" -ForegroundColor Green
}

Write-Host "=== Dual Release Packaging Complete ===" -ForegroundColor Green
