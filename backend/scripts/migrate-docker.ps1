param(
    [string]$ConnectionString,
    [string]$Environment = 'Development',
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$taskPresentation = Join-Path $taskRoot 'backend/src/Presentation'
$taskPreviousConnection = $env:ConnectionStrings__DefaultConnection
$taskHadConnectionOverride = Test-Path Env:\ConnectionStrings__DefaultConnection

if (!$ConnectionString) { $ConnectionString = $taskPreviousConnection }
if (!$ConnectionString) {
    foreach ($taskFile in @('appsettings.json', "appsettings.$Environment.json")) {
        $taskPath = Join-Path $taskPresentation $taskFile
        if (Test-Path -LiteralPath $taskPath) {
            $taskConfig = Get-Content -LiteralPath $taskPath -Raw | ConvertFrom-Json
            if ($taskConfig.ConnectionStrings.DefaultConnection) {
                $ConnectionString = $taskConfig.ConnectionStrings.DefaultConnection
            }
        }
    }
}
if (!$ConnectionString) { throw 'No Core database connection configured. Set ConnectionStrings__DefaultConnection.' }

$taskTarget = [System.Data.Common.DbConnectionStringBuilder]::new()
$taskTarget.set_ConnectionString($ConnectionString)
$taskHost = if ($taskTarget.ContainsKey('Host')) { [string]$taskTarget['Host'] } else { [string]$taskTarget['Server'] }
if ($taskHost -notin @('localhost', '127.0.0.1', '::1')) {
    throw 'This script only migrates local PostgreSQL. Use the separate deployment migration workflow for a remote database.'
}
$taskPort = if ($taskTarget.ContainsKey('Port')) { [string]$taskTarget['Port'] } else { '5432' }
$taskDatabase = [string]$taskTarget['Database']
if ([string]::IsNullOrWhiteSpace($taskDatabase)) { throw 'An explicit database name is required.' }
Write-Output "Applying Core migrations to ${taskHost}:${taskPort}/$taskDatabase (credentials hidden)."

try {
    $env:ConnectionStrings__DefaultConnection = $ConnectionString
    $taskArguments = @(
        'ef', 'database', 'update',
        '--project', (Join-Path $taskRoot 'backend/src/Infrastructure'),
        '--startup-project', $taskPresentation
    )
    if ($NoBuild) { $taskArguments += '--no-build' }
    & dotnet @taskArguments
    if ($LASTEXITCODE -ne 0) { throw 'Core migration failed. Check the reported migration error; do not delete the database or migration history.' }
    Write-Output 'Core migrations are up to date. The backend can now use the current schema.'
}
finally {
    if ($taskHadConnectionOverride) {
        $env:ConnectionStrings__DefaultConnection = $taskPreviousConnection
    }
    else {
        Remove-Item Env:\ConnectionStrings__DefaultConnection -ErrorAction SilentlyContinue
    }
}
