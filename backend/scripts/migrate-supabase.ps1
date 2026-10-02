# Apply all pending EF Core migrations to Supabase PostgreSQL
# Usage:
#   $env:ConnectionStrings__DefaultConnection="Host=...;Port=5432;Database=postgres;Username=...;Password=..."
#   .\scripts\migrate-supabase.ps1

if (-not $env:ConnectionStrings__DefaultConnection) {
    Write-Host "ERROR: ConnectionStrings__DefaultConnection environment variable is not set." -ForegroundColor Red
    Write-Host ""
    Write-Host "Set it first:" -ForegroundColor Yellow
    Write-Host '  $env:ConnectionStrings__DefaultConnection="Host=db.xxx.supabase.co;Port=5432;Database=postgres;Username=postgres;Password=..."' -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}

Write-Host "Applying migrations to Supabase PostgreSQL..." -ForegroundColor Cyan

dotnet ef database update `
    --project src/Infrastructure `
    --startup-project src/Presentation

if ($LASTEXITCODE -eq 0) {
    Write-Host "Done!" -ForegroundColor Green
} else {
    Write-Host "Migration failed." -ForegroundColor Red
}

Write-Host "Cleaning up environment variable..." -ForegroundColor DarkGray
Remove-Item Env:\ConnectionStrings__DefaultConnection
