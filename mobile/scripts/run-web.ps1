param([switch]$NoBrowser)

$ErrorActionPreference = 'Stop'
$frontendPort = 7357
$mobileRoot = Split-Path -Parent $PSScriptRoot
$flutterCommand = Get-Command flutter -CommandType Application -ErrorAction Stop | Select-Object -First 1
$probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $frontendPort)
try { $probe.Start() }
catch { throw "Port $frontendPort is occupied. Stop the previous frontend; this script will not select another port." }
finally { $probe.Stop() }
$url = "http://localhost:$frontendPort"
$browserJob = $null
if (-not $NoBrowser) {
    $chromePath = @($env:CHROME_EXECUTABLE, "$env:ProgramFiles/Google/Chrome/Application/chrome.exe", "${env:ProgramFiles(x86)}/Google/Chrome/Application/chrome.exe", "$env:LOCALAPPDATA/Google/Chrome/Application/chrome.exe") |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
    if ($chromePath) {
        $browserJob = Start-Job -ArgumentList $url, $chromePath -ScriptBlock {
            param($appUrl, $executable)
            for ($attempt = 0; $attempt -lt 360; $attempt++) {
                try {
                    $stamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                    $bootstrap = Invoke-WebRequest -Uri "$appUrl/flutter_bootstrap.js?cwStart=$stamp" -Headers @{ 'Cache-Control' = 'no-cache' } -UseBasicParsing -TimeoutSec 2
                    $main = Invoke-WebRequest -Uri "$appUrl/main.dart.js?cwStart=$stamp" -Headers @{ 'Cache-Control' = 'no-cache' } -UseBasicParsing -TimeoutSec 2
                    if ($bootstrap.StatusCode -eq 200 -and $bootstrap.Content -match '_flutter' -and $main.StatusCode -eq 200 -and $main.Headers['Content-Type'] -match '(application|text)/(javascript|ecmascript)' -and $main.Content -notmatch '^\s*(<!doctype|<html)') {
                        Start-Process -FilePath $executable -ArgumentList "$appUrl/?cwStart=$stamp"
                        return
                    }
                } catch { }
                Start-Sleep -Seconds 1
            }
            Write-Warning "Open $appUrl after compilation finishes."
        }
    }
}
Push-Location -LiteralPath $mobileRoot
try {
    Write-Host "Frontend origin: $url. Keep this terminal open; Ctrl+C stops Flutter."
    & $flutterCommand.Source run -d web-server --web-hostname localhost --web-port $frontendPort --dart-define-from-file=config/google.json
    $runExitCode = $LASTEXITCODE
} finally {
    if ($browserJob) {
        if ($browserJob.State -eq 'Running') { Stop-Job $browserJob }
        Receive-Job $browserJob
        Remove-Job $browserJob
    }
    Pop-Location
}
exit $runExitCode
