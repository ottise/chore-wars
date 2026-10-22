param(
    [switch]$Offline,
    [string]$PostgresAdmin,
    [string]$Kafka,
    [string]$CoreDemoManifest,
    [string]$Python
)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if(!$Python){$Python=Join-Path $taskRoot 'ai-service/.venv/Scripts/python.exe'}
if(!$Offline -and !$PostgresAdmin){throw 'Pass a disposable local PostgreSQL admin DSN, or explicitly choose -Offline.'}
$taskOutput=Join-Path $taskRoot ('artifacts/ai-tests/'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskNames=@('AI_TEST_POSTGRES_ADMIN','AI_TEST_KAFKA','AI_CORE_DEMO_MANIFEST')
$taskPrevious=@{}
foreach($taskName in $taskNames){$taskPrevious[$taskName]=[Environment]::GetEnvironmentVariable($taskName)}
try{
    $env:AI_TEST_POSTGRES_ADMIN=if($Offline){$null}else{$PostgresAdmin}
    $env:AI_TEST_KAFKA=if($Offline){$null}else{$Kafka}
    $env:AI_CORE_DEMO_MANIFEST=$CoreDemoManifest
    & $Python -m pytest (Join-Path $taskRoot 'ai-service/tests') -q --basetemp (Join-Path $taskOutput 'tmp') --junitxml (Join-Path $taskOutput 'python.xml')
    if($LASTEXITCODE -ne 0){throw "AI verification failed. Evidence: $taskOutput"}
    @{offline=[bool]$Offline;postgresRequested=[bool]$PostgresAdmin;kafkaRequested=[bool]$Kafka;coreParityRequested=[bool]$CoreDemoManifest;finishedAt=[DateTime]::UtcNow.ToString('O')}|ConvertTo-Json|Set-Content (Join-Path $taskOutput 'manifest.json')
    Write-Output "AI verification finished. Inspect skipped tests before claiming runtime coverage: $taskOutput"
}finally{
    foreach($taskName in $taskNames){[Environment]::SetEnvironmentVariable($taskName,$taskPrevious[$taskName])}
}
