param(
    [switch]$SkipBuild,
    [string]$Image='chorewars-ai:verification'
)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$taskId=[guid]::NewGuid().ToString('N')
$taskNetwork='cw-ai-contract-'+$taskId
$taskPg=$taskNetwork+'-pg'
$taskApi=$taskNetwork+'-api'
$taskPassword=[guid]::NewGuid().ToString('N')
$taskKey=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$taskOutput=Join-Path $taskRoot ('artifacts/ai-contract/'+$taskId)
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskPrevious=@{}
foreach($taskVariable in @('CHOREWARS_TEST_POSTGRES','CHOREWARS_TEST_AI_URL','CHOREWARS_TEST_AI_KEY')){$taskPrevious[$taskVariable]=[Environment]::GetEnvironmentVariable($taskVariable)}
try{
    if(!$SkipBuild){
        docker build --tag $Image (Join-Path $taskRoot 'ai-service')
        if($LASTEXITCODE -ne 0){throw 'AI image build failed.'}
    }
    docker network create $taskNetwork | Out-Null
    if($LASTEXITCODE -ne 0){throw 'Could not create isolated test network.'}
    docker run --detach --rm --name $taskPg --network $taskNetwork -p '127.0.0.1::5432' -e "POSTGRES_PASSWORD=$taskPassword" -e POSTGRES_DB=chorewars_ai postgres:16 | Out-Null
    if($LASTEXITCODE -ne 0){throw 'Could not create isolated PostgreSQL.'}
    $taskReady=$false
    for($taskAttempt=0;$taskAttempt -lt 60;$taskAttempt++){
        docker exec $taskPg pg_isready -U postgres 2>$null | Out-Null
        if($LASTEXITCODE -eq 0){$taskReady=$true;break}
        Start-Sleep -Milliseconds 500
    }
    if(!$taskReady){throw 'PostgreSQL readiness failed.'}
    $taskUrl="postgresql+psycopg://postgres:${taskPassword}@${taskPg}:5432/chorewars_ai"
    $taskMount="type=bind,source=$(Join-Path $taskRoot 'ai-service/app'),target=/service/app,readonly"
    docker run --rm --network $taskNetwork --mount $taskMount -e "AI_DATABASE_URL=$taskUrl" -e "AI_SERVICE_KEY=$taskKey" $Image python -m app.cli migrate
    if($LASTEXITCODE -ne 0){throw 'AI PostgreSQL migration failed.'}
    docker run --detach --rm --name $taskApi --network $taskNetwork -p '127.0.0.1::8000' --mount $taskMount -e "AI_DATABASE_URL=$taskUrl" -e "AI_SERVICE_KEY=$taskKey" $Image | Out-Null
    if($LASTEXITCODE -ne 0){throw 'Could not start AI API.'}
    $taskReady=$false
    for($taskAttempt=0;$taskAttempt -lt 60;$taskAttempt++){
        docker exec $taskApi python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health/ready',timeout=2)" 2>$null
        if($LASTEXITCODE -eq 0){$taskReady=$true;break}
        Start-Sleep -Milliseconds 500
    }
    if(!$taskReady){throw 'AI API readiness failed.'}
    $taskPgPort=(docker port $taskPg '5432/tcp').Trim().Split(':')[-1]
    $taskApiPort=(docker port $taskApi '8000/tcp').Trim().Split(':')[-1]
    $env:CHOREWARS_TEST_POSTGRES="Host=127.0.0.1;Port=$taskPgPort;Database=postgres;Username=postgres;Password=$taskPassword"
    $env:CHOREWARS_TEST_AI_URL="http://127.0.0.1:$taskApiPort"
    $env:CHOREWARS_TEST_AI_KEY=$taskKey
    dotnet test (Join-Path $taskRoot 'backend/tests/IntegrationTests/IntegrationTests.csproj') --filter 'FullyQualifiedName~AIHousekeeperTests|FullyQualifiedName~AIServiceContractTests|FullyQualifiedName~ManualSwapTransfersResponsibilityOrRejectsNewBounty|FullyQualifiedName~EvidenceVisionAcceptsJsonObjectThroughAuthenticatedHttpWithoutCompletingChore' -m:1 /nr:false -p:UseSharedCompilation=false --results-directory $taskOutput --logger 'trx;LogFileName=ai-contract.trx'
    if($LASTEXITCODE -ne 0){throw "Core/Python contract verification failed. Evidence: $taskOutput"}
    [xml]$taskTrx=Get-Content (Join-Path $taskOutput 'ai-contract.trx') -Raw
    $taskResults=@($taskTrx.SelectNodes("//*[local-name()='UnitTestResult']"))
    if($taskResults.Count -lt 18 -or @($taskResults|Where-Object outcome -ne 'Passed').Count -gt 0){throw 'Required AI/contract/swap tests were missing, skipped or failed.'}
    @{status='PASS';image=$Image;currentSourceMount=$true;testCount=$taskResults.Count;telemetryTransport='INTERNAL_HTTP_IMPORT; KAFKA_VERIFIED_SEPARATELY';finishedAt=[DateTime]::UtcNow.ToString('O')}|ConvertTo-Json|Set-Content (Join-Path $taskOutput 'manifest.json')
    Write-Output "AI container contract verification passed: $taskOutput"
}finally{
    foreach($taskVariable in $taskPrevious.Keys){[Environment]::SetEnvironmentVariable($taskVariable,$taskPrevious[$taskVariable])}
    docker logs $taskApi 2>&1 | Out-File (Join-Path $taskOutput 'ai-api.log')
    docker stop $taskApi $taskPg 2>$null | Out-Null
    docker network rm $taskNetwork 2>$null | Out-Null
}
