# Applies the custom item SQL AFTER the world database has been initialized.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sqlFile = Join-Path $PSScriptRoot 'custom_items_ruRU.sql'
$worldConf = Join-Path $root 'configs\worldserver.conf'
if (-not (Test-Path -LiteralPath $sqlFile)) { throw "SQL file not found: $sqlFile" }
if (-not (Test-Path -LiteralPath $worldConf)) { throw 'Run SETUP_SERVER.cmd before importing items.' }

$conf = [System.IO.File]::ReadAllText($worldConf)
$m = [regex]::Match($conf, '(?m)^WorldDatabaseInfo\s*=\s*"([^"]+)"')
if (-not $m.Success) { throw 'WorldDatabaseInfo missing in worldserver.conf' }
$parts = $m.Groups[1].Value.Split(';')
if ($parts.Count -ne 5) { throw 'Unexpected format for WorldDatabaseInfo.' }
$hostName = $parts[0]
$port = $parts[1]
$user = $parts[2]
$password = $parts[3]
$db = $parts[4]
if ($hostName -ne '127.0.0.1' -or $db -ne 'acore_world') {
    throw 'Only the local demo database acore_world is supported by this helper.'
}

$mysqlMatch = [regex]::Match($conf, '(?m)^MySQLExecutable\s*=\s*"([^"]+)"')
$mysql = if ($mysqlMatch.Success) { $mysqlMatch.Groups[1].Value } else { '' }
if ($mysql) { $mysql = $mysql.Replace('/', '\') }
if (-not $mysql -or -not (Test-Path -LiteralPath $mysql)) {
    $cmd = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if ($cmd) { $mysql = $cmd.Source }
}
if (-not $mysql -or -not (Test-Path -LiteralPath $mysql)) {
    throw 'MySQL client not found. Install MySQL Server 8.4 or add mysql.exe to PATH.'
}

Write-Host 'This will add 3 custom items (IDs 910001-910003) and ruRU names.'
Write-Host 'Back up your local acore_world database before importing custom SQL.'
$answer = Read-Host 'Continue? Type YES'
if ($answer -ne 'YES') { Write-Host 'Cancelled'; exit 1 }

# Temporary MySQL defaults file avoids placing database credentials on the
# process command line. Kept in TEMP only while the query is running.
$clientFile = Join-Path $env:TEMP ("acore-client-{0}.cnf" -f ([guid]::NewGuid().ToString('N')))
$clientData = "[client]" + [Environment]::NewLine + "user=$user" +
  [Environment]::NewLine + "password=$password" +
  [Environment]::NewLine + "host=$hostName" +
  [Environment]::NewLine + "port=$port" +
  [Environment]::NewLine + "protocol=tcp" + [Environment]::NewLine
try {
    [System.IO.File]::WriteAllText($clientFile, $clientData, (New-Object System.Text.UTF8Encoding($false)))
    $check = & $mysql "--defaults-extra-file=$clientFile" '--batch' '--skip-column-names' "--database=$db" '--execute=SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name IN ("item_template","item_template_locale");' 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Cannot query world database: $($check -join ' ')" }
    if (($check | Select-Object -Last 1).ToString().Trim() -ne '2') {
        throw 'World database is not fully initialized. Start worldserver, confirm initial database import, then try again.'
    }

    # Send SQL as UTF-8 via standard input; password never appears in a CLI option.
    $oldOutputEncoding = $OutputEncoding
    try {
        $OutputEncoding = New-Object System.Text.UTF8Encoding($false)
        Get-Content -LiteralPath $sqlFile -Raw -Encoding UTF8 | & $mysql "--defaults-extra-file=$clientFile" '--default-character-set=utf8mb4' "--database=$db"
        if ($LASTEXITCODE -ne 0) { throw 'Custom SQL import failed. Review the MySQL error above.' }
    } finally {
        $OutputEncoding = $oldOutputEncoding
    }
    Write-Host 'Custom item SQL imported successfully.' -ForegroundColor Green
    Write-Host 'Restart worldserver, then use GM .additem 910001, 910002, 910003.'
}
finally {
    Remove-Item -LiteralPath $clientFile -Force -ErrorAction SilentlyContinue
}
