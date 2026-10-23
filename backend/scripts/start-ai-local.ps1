param([switch]$NoBuild)

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$taskEnvPath = Join-Path $taskRoot '.env.ai.local'
if (-not (Test-Path -LiteralPath $taskEnvPath)) {
    throw 'Create .env.ai.local from .env.example and set the AI credentials first.'
}
$taskValues = @{}
foreach ($line in [System.IO.File]::ReadAllLines($taskEnvPath)) {
    if ($line.TrimStart().StartsWith('#') -or -not $line.Contains('=')) { continue }
    $parts = $line.Split('=', 2)
    $taskValues[$parts[0].Trim()] = $parts[1].Trim().Trim('"').Trim("'")
}
if ([string]::IsNullOrWhiteSpace($taskValues['GEMINI_API_KEY']) -or
    ([string]$taskValues['AI_SERVICE_KEY']).Length -lt 32 -or
    [string]::IsNullOrWhiteSpace($taskValues['AI_POSTGRES_PASSWORD'])) {
    throw 'Set GEMINI_API_KEY, AI_SERVICE_KEY (at least 32 characters) and AI_POSTGRES_PASSWORD in .env.ai.local.'
}
$taskConfig = @{ AI = @{ Enabled = $true; BaseUrl = 'http://127.0.0.1:8011'; ServiceKey = $taskValues['AI_SERVICE_KEY'] } }
$taskConfigPath = Join-Path $taskRoot 'backend/src/Presentation/appsettings.AI.local.json'
[System.IO.File]::WriteAllText($taskConfigPath, ($taskConfig | ConvertTo-Json))

Push-Location -LiteralPath $taskRoot
try {
    $taskArgs = @('compose', '--env-file', '.env.ai.local', '-f', 'docker-compose.yml', '-f', 'docker-compose.ai.yml', '-f', 'docker-compose.ai.local.yml', 'up', '-d')
    if (-not $NoBuild) { $taskArgs += '--build' }
    $taskArgs += @('ai-api', 'ai-worker', 'ai-trainer')
    & docker @taskArgs
    if ($LASTEXITCODE -ne 0) { throw 'AI container startup failed.' }
    $taskReady = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        try {
            $taskHealth = Invoke-RestMethod -Uri 'http://127.0.0.1:8011/health/ready' -TimeoutSec 3
            if ($taskHealth.status -eq 'ready' -and $taskHealth.provider_configured) { $taskReady = $true; break }
        } catch { }
        Start-Sleep -Seconds 2
    }
    if (-not $taskReady) { throw 'AI did not become ready. Check the AI container status.' }
    Write-Host 'AI is ready at http://127.0.0.1:8011. Restart the local Development backend to load its AI settings.'
} finally {
    Pop-Location
}
