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
$device = if ($NoBrowser) { 'web-server' } else { 'chrome' }
$flutterArguments = @('run', '-d', $device, '--web-hostname', 'localhost', '--web-port', $frontendPort, '--dart-define-from-file=config/google.json')
if ($NoBrowser) {
    # The external-browser debug client must not depend on a WebSocket handshake.
    $flutterArguments += @('--web-server-debug-injected-client-protocol=sse', '--web-server-debug-backend-protocol=sse')
}
Push-Location -LiteralPath $mobileRoot
try {
    Write-Host "Frontend origin: $url. Keep this terminal open; Ctrl+C stops Flutter."
    & $flutterCommand.Source @flutterArguments
    $runExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $runExitCode
