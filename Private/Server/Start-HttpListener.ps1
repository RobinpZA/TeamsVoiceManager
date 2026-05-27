function Start-HttpListener {
    [CmdletBinding()]
    param(
        [ValidateRange(1, 65535)]
        [int]$Port = 8080
    )
    $prefix = "http://127.0.0.1:$Port/"
    $script:HttpListener = [System.Net.HttpListener]::new()
    $script:HttpListener.Prefixes.Add($prefix)
    try { $script:HttpListener.Start() }
    catch { Write-Error "Failed to start HTTP listener on port $Port. Is the port in use? Error: $_"; throw }
    Write-Host "  Listening on $prefix" -ForegroundColor Green
    while ($script:HttpListener.IsListening) {
        try {
            $contextTask = $script:HttpListener.GetContextAsync()
            while (-not $contextTask.AsyncWaitHandle.WaitOne(200)) { }
            $context = $contextTask.GetAwaiter().GetResult()
            Invoke-RequestRouter -Context $context
        } catch [System.ObjectDisposedException] { break }
        catch [System.Net.HttpListenerException] { break }
        catch { Write-Warning "Request error: $_" }
    }
}
