$choreWarsShortcutRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\', '/')
$choreWarsShortcutSdk = (Get-Command flutter -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$choreWarsShortcutLauncher = Join-Path $PSScriptRoot 'run-web.ps1'
$choreWarsShortcutCommand = {
    $currentFolder = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.Path.TrimEnd('\', '/')
    $insideProject = $currentFolder.Equals($choreWarsShortcutRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $currentFolder.StartsWith($choreWarsShortcutRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
    if ($insideProject -and $args.Count -eq 1 -and $args[0] -eq 'run') {
        & $choreWarsShortcutLauncher
    } else {
        & $choreWarsShortcutSdk @args
    }
}.GetNewClosure()
Set-Item -Path Function:global:flutter -Value $choreWarsShortcutCommand
