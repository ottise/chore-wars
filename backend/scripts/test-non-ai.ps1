param(
    [string]$PostgresImage = 'postgres:16-alpine',
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$taskRunId = [guid]::NewGuid().ToString('N')
$taskContainer = 'cw-non-ai-test-' + $taskRunId
if (!$OutputDirectory) { $OutputDirectory = Join-Path $taskRoot "artifacts/runtime/$taskRunId/postgres" }
$taskOutput = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskPreviousConnection = $env:CHOREWARS_TEST_POSTGRES
$taskStarted = $false
try {
    docker info --format '{{.ServerVersion}}' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Start Docker Desktop before running this script.' }
    docker run --detach --rm --name $taskContainer -e POSTGRES_DB=chore_test -e POSTGRES_USER=chore_test -e POSTGRES_PASSWORD=local_test_only -p '127.0.0.1::5432' $PostgresImage | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not start disposable PostgreSQL.' }
    $taskStarted = $true
    $taskReady = $false
    for ($taskAttempt = 0; $taskAttempt -lt 60; $taskAttempt++) {
        docker exec $taskContainer pg_isready -U chore_test -d chore_test 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $taskReady = $true; break }
        Start-Sleep -Milliseconds 500
    }
    if (!$taskReady) { throw 'Disposable PostgreSQL did not become ready.' }
    $taskPort = (docker port $taskContainer '5432/tcp').Trim().Split(':')[-1]
    $env:CHOREWARS_TEST_POSTGRES = "Host=127.0.0.1;Port=$taskPort;Database=chore_test;Username=chore_test;Password=local_test_only"
    @{runId=$taskRunId; postgresImage=$PostgresImage; startedAt=[DateTime]::UtcNow.ToString('O')} | ConvertTo-Json | Set-Content (Join-Path $taskOutput 'manifest.json')
    foreach ($taskProject in @('UnitTests','IntegrationTests')) {
        dotnet test (Join-Path $taskRoot "backend/tests/$taskProject/$taskProject.csproj") --nologo --verbosity minimal -m:1 -nodeReuse:false -p:UseSharedCompilation=false --results-directory $taskOutput --logger "trx;LogFileName=$taskProject.trx"
        if ($LASTEXITCODE -ne 0) { throw "Verification failed: $taskProject. Evidence: $taskOutput" }
    }
    [xml]$taskTrx = Get-Content (Join-Path $taskOutput 'IntegrationTests.trx') -Raw
    $taskResults = @($taskTrx.SelectNodes("//*[local-name()='UnitTestResult']"))
    $taskRequired = @(
        'CompetingCompletionsCreditKarmaAndOutboxOnce',
        'SimultaneousConfirmationsActivateOnlyAfterAllThreePersist',
        'ConcurrentRewardRedemptionsCannotOverspend',
        'PaymentReceiptRetryDoesNotChangeAuditTime',
        'RealHttpPipelineProtectsHouseAndPrivateMedia',
        'LegacyRoutineKeepsEndOfDayAndGetsAnEmptyCustomCalendar'
    )
    foreach ($taskName in $taskRequired) {
        $taskMatch = @($taskResults | Where-Object { $_.testName.EndsWith($taskName) })
        if ($taskMatch.Count -ne 1 -or $taskMatch[0].outcome -ne 'Passed') { throw "Required test missing, skipped or failed: $taskName" }
    }
    Write-Output "All 6 required PostgreSQL tests passed. Evidence: $taskOutput"
}
finally {
    $env:CHOREWARS_TEST_POSTGRES = $taskPreviousConnection
    if ($taskStarted) {
        docker logs $taskContainer 2>&1 | Out-File (Join-Path $taskOutput 'postgres.log')
        docker stop $taskContainer | Out-Null
    }
}
