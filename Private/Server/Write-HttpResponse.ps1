function Write-JsonResponse {
    [CmdletBinding()]
    param([System.Net.HttpListenerContext]$Context, [object]$Data, [int]$StatusCode = 200)
    $response = $Context.Response
    $response.StatusCode = $StatusCode
    $response.ContentType = 'application/json; charset=utf-8'
    $response.AddHeader('Cache-Control', 'no-cache')
    $json = $Data | ConvertTo-JsonSafe
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
    $response.ContentLength64 = $buffer.Length
    try { $response.OutputStream.Write($buffer, 0, $buffer.Length) }
    finally { $response.OutputStream.Close() }
}

function Write-HtmlFileResponse {
    [CmdletBinding()]
    param([System.Net.HttpListenerContext]$Context, [string]$RelativePath)
    $portalRoot = Join-Path $script:ModuleRoot 'Assets' 'portal'
    $filePath   = Join-Path $portalRoot $RelativePath
    # Path traversal guard: resolve both paths and verify the file stays inside the portal root
    $resolvedRoot = (Resolve-Path $portalRoot -ErrorAction SilentlyContinue)?.Path
    $resolvedFile = (Resolve-Path $filePath   -ErrorAction SilentlyContinue)?.Path
    if (-not $resolvedFile -or -not $resolvedRoot -or -not $resolvedFile.StartsWith($resolvedRoot)) {
        Write-JsonResponse -Context $Context -Data @{error='Forbidden'} -StatusCode 403; return
    }
    if (-not (Test-Path $resolvedFile)) { Write-JsonResponse -Context $Context -Data @{error="File not found: $RelativePath"} -StatusCode 404; return }
    $response = $Context.Response
    $response.StatusCode = 200
    $response.ContentType = 'text/html; charset=utf-8'
    $response.AddHeader('Cache-Control', 'no-cache')
    $content = [System.IO.File]::ReadAllBytes($resolvedFile)
    $response.ContentLength64 = $content.Length
    try { $response.OutputStream.Write($content, 0, $content.Length) } finally { $response.OutputStream.Close() }
}

function Write-StaticFileResponse {
    [CmdletBinding()]
    param([System.Net.HttpListenerContext]$Context, [string]$RelativePath)
    $portalRoot = Join-Path $script:ModuleRoot 'Assets' 'portal'
    $filePath   = Join-Path $portalRoot $RelativePath
    # Path traversal guard
    $resolvedRoot = (Resolve-Path $portalRoot -ErrorAction SilentlyContinue)?.Path
    $resolvedFile = (Resolve-Path $filePath   -ErrorAction SilentlyContinue)?.Path
    if (-not $resolvedFile -or -not $resolvedRoot -or -not $resolvedFile.StartsWith($resolvedRoot)) {
        Write-JsonResponse -Context $Context -Data @{error='Forbidden'} -StatusCode 403; return
    }
    if (-not (Test-Path $resolvedFile)) { Write-JsonResponse -Context $Context -Data @{error="File not found: $RelativePath"} -StatusCode 404; return }
    $extension = [System.IO.Path]::GetExtension($resolvedFile).ToLower()
    $contentType = switch ($extension) {
        '.css'  { 'text/css; charset=utf-8' }
        '.js'   { 'application/javascript; charset=utf-8' }
        '.json' { 'application/json; charset=utf-8' }
        '.svg'  { 'image/svg+xml' }
        '.png'  { 'image/png' }
        '.ico'  { 'image/x-icon' }
        default { 'application/octet-stream' }
    }
    $response = $Context.Response
    $response.StatusCode = 200
    $response.ContentType = $contentType
    if ($extension -in @('.css','.js')) { $response.AddHeader('Cache-Control','no-cache') }
    elseif ($extension -in @('.svg','.png')) { $response.AddHeader('Cache-Control','public, max-age=3600') }
    $content = [System.IO.File]::ReadAllBytes($resolvedFile)
    $response.ContentLength64 = $content.Length
    try { $response.OutputStream.Write($content, 0, $content.Length) } finally { $response.OutputStream.Close() }
}
