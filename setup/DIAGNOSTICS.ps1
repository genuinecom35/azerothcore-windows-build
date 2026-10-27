# Basic offline readiness check. Does not modify MySQL or configuration.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$errors = New-Object System.Collections.Generic.List[string]
function Check([string]$rel, [string]$label) {
    $full = Join-Path $root $rel
    if (Test-Path -LiteralPath $full) {
        Write-Host "[OK] $label" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $label : $rel" -ForegroundColor Yellow
        $errors.Add($label)
    }
}
Write-Host "AzerothCore directory: $root"
Check 'authserver.exe' 'Login server'
Check 'worldserver.exe' 'Game world server'
Check 'configs\authserver.conf' 'Auth configuration'
Check 'configs\worldserver.conf' 'World configuration'
Check 'SQL_SOURCE\data\sql\base\db_auth' 'Auth SQL sources'
Check 'SQL_SOURCE\data\sql\base\db_world' 'World SQL sources'
Check 'Data\dbc' 'Required DBC client files'
Check 'Data\maps' 'Required maps'
Check 'Data\vmaps' 'Recommended VMaps'
Check 'Data\mmaps' 'Recommended MMaps'
if ($errors.Count -gt 0) {
    Write-Host "$($errors.Count) required/recommended components missing. Consult README_RU.txt." -ForegroundColor Yellow
} else {
    Write-Host 'Files found. Database connectivity and actual server boot must still be tested.' -ForegroundColor Green
}
