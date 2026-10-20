param()
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$taskRun=[guid]::NewGuid().ToString('N')
$taskContainer='cw-runtime-kafka-'+$taskRun
$taskOutput=Join-Path $taskRoot "artifacts/runtime/$taskRun/kafka"
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskOldKafka=$env:CHOREWARS_TEST_KAFKA
$taskOldContainer=$env:CHOREWARS_TEST_KAFKA_CONTAINER
$taskStarted=$false
try {
    docker info --format '{{.ServerVersion}}' | Out-Null
    if($LASTEXITCODE -ne 0) { throw 'Docker engine is required.' }
    $taskListener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
    $taskListener.Start();$taskPort=$taskListener.LocalEndpoint.Port;$taskListener.Stop()
    docker run --detach --rm --name $taskContainer -p "127.0.0.1:${taskPort}:9092" -e KAFKA_NODE_ID=1 -e KAFKA_PROCESS_ROLES=broker,controller -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093 -e 'KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093' -e "KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://127.0.0.1:$taskPort" -e 'KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT' -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 -e KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=0 -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 apache/kafka:3.7.0 | Out-Null
    if($LASTEXITCODE -ne 0) { throw 'Could not create disposable Kafka container.' }
    $taskStarted=$true
    $taskReady=$false
    for($taskAttempt=0;$taskAttempt -lt 120;$taskAttempt++) {
        $taskLog=docker logs $taskContainer 2>&1 | Out-String
        if($taskLog.Contains('Kafka Server started')) { $taskReady=$true; break }
        Start-Sleep -Milliseconds 500
    }
    if(!$taskReady) { throw 'Kafka did not become ready.' }
    $env:CHOREWARS_TEST_KAFKA="127.0.0.1:$taskPort"
    $env:CHOREWARS_TEST_KAFKA_CONTAINER=$taskContainer
    & (Join-Path $PSScriptRoot 'test-non-ai.ps1') -OutputDirectory $taskOutput
    [xml]$taskTrx=Get-Content (Join-Path $taskOutput 'IntegrationTests.trx') -Raw
    $taskResults=@($taskTrx.SelectNodes("//*[local-name()='UnitTestResult']") | Where-Object { $_.testName.Contains('RealKafkaTests.') })
    if($taskResults.Count -lt 10 -or @($taskResults | Where-Object { $_.outcome -ne 'Passed' }).Count -gt 0) { throw 'Real Kafka verification missing, failed or skipped.' }
    Write-Output "Kafka/PostgreSQL evidence: $taskOutput"
}
finally {
    $env:CHOREWARS_TEST_KAFKA=$taskOldKafka
    $env:CHOREWARS_TEST_KAFKA_CONTAINER=$taskOldContainer
    if($taskStarted) {
        docker logs $taskContainer 2>&1 | Out-File (Join-Path $taskOutput 'kafka.log')
        docker stop $taskContainer | Out-Null
    }
}
