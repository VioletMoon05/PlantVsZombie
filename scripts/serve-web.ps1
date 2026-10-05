param(
    [ValidateRange(1, 65535)]
    [int]$Port = 8080
)

$ErrorActionPreference = 'Stop'
$webRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\build\web'))
$indexPath = Join-Path $webRoot 'index.html'

if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
    throw "Web build not found at '$webRoot'. Run scripts\build-web.ps1 first."
}

$mimeTypes = @{
    '.html'       = 'text/html; charset=utf-8'
    '.js'         = 'text/javascript; charset=utf-8'
    '.wasm'       = 'application/wasm'
    '.webmanifest'= 'application/manifest+json; charset=utf-8'
    '.json'       = 'application/json; charset=utf-8'
    '.png'        = 'image/png'
    '.jpg'        = 'image/jpeg'
    '.jpeg'       = 'image/jpeg'
    '.ico'        = 'image/x-icon'
}

$rootPrefix = $webRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")

try {
    $listener.Start()
    Write-Host "Serving $webRoot at http://127.0.0.1:$Port/"
    Write-Host 'Press Ctrl+C to stop.'

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $response = $context.Response

        try {
            if ($context.Request.HttpMethod -notin @('GET', 'HEAD')) {
                $response.StatusCode = 405
                $response.Headers['Allow'] = 'GET, HEAD'
            } else {
                $relativePath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath).TrimStart('/')
                if (-not $relativePath) { $relativePath = 'index.html' }

                $filePath = [System.IO.Path]::GetFullPath((Join-Path $webRoot $relativePath))
                if (-not $filePath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $response.StatusCode = 403
                } else {
                    if (Test-Path -LiteralPath $filePath -PathType Container) {
                        $filePath = Join-Path $filePath 'index.html'
                    }

                    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                        $response.StatusCode = 404
                    } else {
                        $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
                        if ($mimeTypes.ContainsKey($extension)) {
                            $response.ContentType = $mimeTypes[$extension]
                        } else {
                            $response.ContentType = 'application/octet-stream'
                        }

                        $response.StatusCode = 200
                        $response.Headers['Cache-Control'] = 'no-store'
                        $bytes = [System.IO.File]::ReadAllBytes($filePath)
                        $response.ContentLength64 = $bytes.Length
                        if ($context.Request.HttpMethod -ne 'HEAD') {
                            $response.OutputStream.Write($bytes, 0, $bytes.Length)
                        }
                    }
                }
            }
        } catch {
            $response.StatusCode = 500
            $response.ContentType = 'text/plain; charset=utf-8'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes('Web server error.')
            $response.ContentLength64 = $bytes.Length
            try { $response.OutputStream.Write($bytes, 0, $bytes.Length) } catch { }
            Write-Warning $_.Exception.Message
        } finally {
            $response.Close()
        }
    }
} finally {
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
}
