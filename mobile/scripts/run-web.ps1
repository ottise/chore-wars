param(
    [ValidateRange(0, 65535)]
    [int]$Port = 0,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$mobileRoot = Split-Path -Parent $PSScriptRoot
$flutterCommand = Get-Command flutter -CommandType Application -ErrorAction Stop | Select-Object -First 1
$runArguments = @('run', '--dart-define-from-file=config/google.json')
if ($NoBrowser) { $runArguments += @('-d', 'web-server') }
if ($Port -gt 0) { $runArguments += @('--web-port', "$Port") }
Push-Location -LiteralPath $mobileRoot
try {
    & $flutterCommand.Source @runArguments
    $runExitCode = $LASTEXITCODE
} finally { Pop-Location }
exit $runExitCode
