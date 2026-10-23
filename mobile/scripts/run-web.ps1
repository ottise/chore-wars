param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 8080,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$mobileRoot = Split-Path -Parent $PSScriptRoot
$flutterCommand = Get-Command flutter -ErrorAction Stop
$probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
try { $probe.Start() }
catch { throw "Port $Port is unavailable. Run this script with -Port 8081 or another free port." }
finally { $probe.Stop() }

$url = "http://localhost:$Port"
$browserJob = $null
if (-not $NoBrowser) {
    $chromePath = @(
        $env:CHROME_EXECUTABLE,
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
    if ($chromePath) {
        $browserJob = Start-Job -ArgumentList $url, $chromePath -ScriptBlock {
            param($appUrl, $executable)
            for ($attempt = 0; $attempt -lt 360; $attempt++) {
                $ready = $false
                try {
                    $bootstrap = Invoke-WebRequest -Uri "$appUrl/flutter_bootstrap.js" -UseBasicParsing -TimeoutSec 2
                    $ready = $bootstrap.StatusCode -eq 200 -and $bootstrap.Content -match '_flutter'
                } catch { }
                if ($ready) {
                    Start-Process -FilePath $executable -ArgumentList $appUrl
                    Write-Output "Chrome opened at $appUrl"
                    return
                }
                Start-Sleep -Seconds 1
            }
            Write-Warning "Open $appUrl manually after Flutter finishes compiling."
        }
    } else { Write-Warning "Chrome executable not found. Open $url manually after compilation." }
}

$runExitCode = 0
Push-Location -LiteralPath $mobileRoot
try {
    if ($browserJob) { Write-Host "Chrome will open $url after the app is ready. First compilation can take several minutes." }
    else { Write-Host "Open $url after Flutter finishes compiling." }
    Write-Host 'Using web-server to avoid the Chrome/DWDS debugger timeout. Dart breakpoint debugging is limited.'
    Write-Host 'Use -NoBrowser to serve without opening a browser. Keep this terminal running; Ctrl+C stops it.'
    & $flutterCommand.Source run -d web-server --web-hostname localhost --web-port $Port
    $runExitCode = $LASTEXITCODE
}
finally {
    if ($browserJob) {
        if ($browserJob.State -eq 'Running') { Stop-Job -Job $browserJob }
        Receive-Job -Job $browserJob
        Remove-Job -Job $browserJob
    }
    Pop-Location
}
exit $runExitCode
