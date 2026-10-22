param(
    [string]$OutputDirectory,
    [string]$Python,
    [switch]$BudgetComplete
)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
if(!$env:CHOREWARS_DEMO_POSTGRES_ADMIN){throw 'Set CHOREWARS_DEMO_POSTGRES_ADMIN to a disposable local PostgreSQL server.'}
if(!$env:AI_DATABASE_URL){throw 'Set AI_DATABASE_URL to the separate AI PostgreSQL database and apply Alembic migrations first.'}
if(!$env:AI_SERVICE_KEY){throw 'Set AI_SERVICE_KEY for the internal CLI configuration.'}
if(!$OutputDirectory){$OutputDirectory=Join-Path $taskRoot ('artifacts/ai-cohort/'+[guid]::NewGuid().ToString('N'))}
if(!$Python){$Python=Join-Path $taskRoot 'ai-service/.venv/Scripts/python.exe'}
$taskOutput=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
dotnet build (Join-Path $PSScriptRoot 'AIDemo.csproj') -m:1 /nr:false -p:UseSharedCompilation=false
if($LASTEXITCODE -ne 0){throw 'Build the demo tool successfully before creating a cohort.'}
$taskArguments=@('-u','-m','app.cli','demo-evaluate')
foreach($taskSeed in 42..61){
    $taskSeedOutput=Join-Path $taskOutput "seed-$taskSeed"
    $taskManifest=Join-Path $taskSeedOutput 'manifest.json'
    if(!(Test-Path -LiteralPath $taskManifest)){
        if((Test-Path -LiteralPath $taskSeedOutput) -and @(Get-ChildItem -LiteralPath $taskSeedOutput).Count -gt 0){throw "Incomplete seed export preserved: $taskSeedOutput. Use a new output directory for this seed."}
        dotnet run --no-build --project (Join-Path $PSScriptRoot 'AIDemo.csproj') -- --seed $taskSeed --months 14 --output $taskSeedOutput
        if($LASTEXITCODE -ne 0){throw "Core business demo failed at seed $taskSeed; earlier evidence is preserved."}
    }
    $taskArguments+=@('--manifest',$taskManifest)
}
if($BudgetComplete){$taskArguments+=@('--mode','budget')}
& $Python @taskArguments
if($LASTEXITCODE -ne 0){throw 'AI cohort evaluation failed; completed runs remain immutable in AI PostgreSQL.'}
