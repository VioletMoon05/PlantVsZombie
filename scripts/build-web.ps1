$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $projectRoot 'build\web'
$goCommand = Get-Command go -ErrorAction SilentlyContinue

if (-not $goCommand) {
    throw 'Go is not installed or is not on PATH. Install Go 1.24+ and reopen PowerShell.'
}

$versionText = (& go version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Could not run Go: $versionText"
}

if ($versionText -notmatch 'go(?<major>\d+)\.(?<minor>\d+)(?:\.(?<patch>\d+))?') {
    throw "Could not read the Go version from: $versionText"
}

$goMajor = [int]$Matches.major
$goMinor = [int]$Matches.minor
if (($goMajor -lt 1) -or (($goMajor -eq 1) -and ($goMinor -lt 24))) {
    throw "Go 1.24 or newer is required. Found: $versionText"
}

$null = New-Item -ItemType Directory -Path $outputDir -Force
$previousGoos = $env:GOOS
$previousGoarch = $env:GOARCH

try {
    $env:GOOS = 'js'
    $env:GOARCH = 'wasm'
    Write-Host 'Building the complete game for WebAssembly...'
    & go -C $projectRoot build -trimpath -ldflags '-s -w' -o (Join-Path $outputDir 'pvz.wasm') .
    if ($LASTEXITCODE -ne 0) {
        throw 'WebAssembly build failed.'
    }
}
finally {
    $env:GOOS = $previousGoos
    $env:GOARCH = $previousGoarch
}

$goRoot = (& go env GOROOT 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $goRoot) {
    throw 'Could not locate GOROOT to copy wasm_exec.js.'
}

$wasmExecCandidates = @(
    (Join-Path $goRoot 'lib\wasm\wasm_exec.js'),
    (Join-Path $goRoot 'misc\wasm\wasm_exec.js')
)
$wasmExec = $wasmExecCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $wasmExec) {
    throw "wasm_exec.js was not found under GOROOT: $goRoot"
}

Copy-Item -LiteralPath (Join-Path $projectRoot 'web\index.html') -Destination $outputDir -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'web\manifest.webmanifest') -Destination $outputDir -Force
Copy-Item -LiteralPath $wasmExec -Destination (Join-Path $outputDir 'wasm_exec.js') -Force

$buildVersion = [DateTime]::UtcNow.ToString('yyyyMMddHHmmssfffffff')
$serviceWorkerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'web\sw.js') -Raw
$serviceWorker = $serviceWorkerSource.Replace('__PVZ_CACHE_VERSION__', $buildVersion)
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $outputDir 'sw.js'), $serviceWorker, $utf8WithoutBom)

$iconsSource = Join-Path $projectRoot 'assets\icons\web'
$iconsOutput = Join-Path $outputDir 'icons'
$null = New-Item -ItemType Directory -Path $iconsOutput -Force
Get-ChildItem -LiteralPath $iconsSource -File | Copy-Item -Destination $iconsOutput -Force

Write-Host ''
Write-Host "Web build ready: $outputDir"
Write-Host 'Serve this folder over HTTP/HTTPS; do not open index.html with file://.'
