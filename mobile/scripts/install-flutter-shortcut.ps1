$ErrorActionPreference = 'Stop'
$loader = Join-Path $PSScriptRoot 'enable-flutter-shortcut.ps1'
$documentsFolder = [Environment]::GetFolderPath('MyDocuments')
$profileTargets = @($PROFILE.CurrentUserAllHosts, (Join-Path $documentsFolder 'PowerShell/profile.ps1'), (Join-Path $documentsFolder 'WindowsPowerShell/profile.ps1')) | Select-Object -Unique
$startMarker = '# BEGIN chore-wars flutter shortcut'
$endMarker = '# END chore-wars flutter shortcut'
$escapedLoader = $loader.Replace("'", "''")
$block = "$startMarker`r`nif (Test-Path -LiteralPath '$escapedLoader') { . '$escapedLoader' }`r`n$endMarker"
foreach ($target in $profileTargets) {
    $content = if (Test-Path -LiteralPath $target) { [IO.File]::ReadAllText($target) } else { '' }
    if ($content.Contains($startMarker) -ne $content.Contains($endMarker)) { throw "Incomplete project shortcut block: $target" }
    if (-not $content.Contains($startMarker) -and $content -match '(?im)^\s*(function\s+(?:global:)?flutter\b|(?:Set-Alias|New-Alias)\s+(?:-Name\s+)?flutter\b)') { throw "Existing Flutter shortcut needs review: $target" }
}
foreach ($target in $profileTargets) {
    $content = if (Test-Path -LiteralPath $target) { [IO.File]::ReadAllText($target) } else { '' }
    if ($content.Contains($startMarker)) {
        $pattern = '(?s)' + [regex]::Escape($startMarker) + '.*?' + [regex]::Escape($endMarker)
        $content = [regex]::Replace($content, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $block })
    } else { $content += "`r`n" + $block + "`r`n" }
    [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
    [IO.File]::WriteAllText($target, $content, [Text.UTF8Encoding]::new($true))
    Write-Host "Configured fixed-port Flutter shortcut: $target"
}
Write-Host 'Open a new PowerShell terminal. Bare flutter run in this project uses localhost:7357.'
