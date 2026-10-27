# AzerothCore 3.3.5a - local Windows first-run setup
# Run SETUP_SERVER.cmd from the unpacked GitHub Actions artifact.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path $PSScriptRoot).Path
$cfgDir = Join-Path $root 'configs'
$dataDir = Join-Path $root 'Data'
$sqlDir = Join-Path $root 'SQL_SOURCE\data\sql'

function Need([string]$path, [string]$label) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing $label : $path" }
}
function Find-MySql {
    $cmd = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe',
        'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
    )
    foreach ($p in $candidates) { if (Test-Path -LiteralPath $p) { return $p } }
    throw 'MySQL client mysql.exe not found. Install MySQL Server 8.4 LTS and run SETUP_SERVER.cmd again.'
}
function Set-ConfOption([string]$path, [string]$name, [string]$value) {
    $s = [System.IO.File]::ReadAllText($path)
    $pattern = '(?m)^' + [regex]::Escape($name) + '\s*=.*$'
    if (-not [regex]::IsMatch($s, $pattern)) {
        throw "Option $name not found in $path - the config format may have changed."
    }
    $s = [regex]::Replace($s, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        return "$name = $value"
    })
    [System.IO.File]::WriteAllText($path, $s, (New-Object System.Text.UTF8Encoding($false)))
}
function PathForConfig([string]$p) { return $p.Replace('\','/') }
function Require-Clean([string]$p) {
    if (Test-Path -LiteralPath $p) {
        throw "Configuration already exists: $p. Setup stopped to avoid changing an existing server. Consult README_RU.txt."
    }
}

Write-Host ''
Write-Host '=== AzerothCore 3.3.5a: local server setup ===' -ForegroundColor Cyan
Need (Join-Path $root 'authserver.exe') 'authserver.exe'
Need (Join-Path $root 'worldserver.exe') 'worldserver.exe'
Need (Join-Path $cfgDir 'authserver.conf.dist') 'authserver.conf.dist'
Need (Join-Path $cfgDir 'worldserver.conf.dist') 'worldserver.conf.dist'
Need $sqlDir 'SQL database source (SQL_SOURCE\data\sql)'
Require-Clean (Join-Path $cfgDir 'authserver.conf')
Require-Clean (Join-Path $cfgDir 'worldserver.conf')

$mysql = Find-MySql
Write-Host "MySQL client: $mysql"
Write-Host 'A running local MySQL 8.4 server on 127.0.0.1:3306 is required.'
Write-Host 'The MySQL root password is requested by mysql.exe and is NOT saved.'
Write-Host 'Only a NEW empty local server will be initialized.'
$ok = Read-Host 'Initialize new databases acore_auth, acore_world, acore_characters? (YES/no)'
if ($ok -ne 'YES') { Write-Host 'Cancelled. Enter YES when ready.'; exit 1 }

Write-Host 'Enter your MySQL root password for checking existing databases:'
$checkQuery = "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name IN ('acore_auth','acore_world','acore_characters');"
$result = @(& $mysql '--protocol=tcp' '-h' '127.0.0.1' '-P' '3306' '-u' 'root' '-p' '--batch' '--skip-column-names' "--execute=$checkQuery")
if ($LASTEXITCODE -ne 0) {
    throw "Cannot connect to local MySQL as root. Verify service and password. Details: $($result -join ' ')"
}
$numberText = (($result | Where-Object { $_ -match '^\s*\d+\s*$' }) | Select-Object -Last 1)
if ($null -eq $numberText) { throw 'Could not verify whether databases already exist. Aborting.' }
if ([int]$numberText.Trim() -gt 0) {
    throw 'One or more AzerothCore databases already exist. Nothing changed. Back them up and configure them manually.'
}
$bytes = New-Object byte[] 24
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
$dbPassword = [BitConverter]::ToString($bytes).Replace('-','').ToLowerInvariant()
$dbUser = 'acore_' + $dbPassword.Substring(0, 8)

$createSql = @"
CREATE DATABASE acore_auth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE acore_characters CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE acore_world CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$dbUser'@'localhost' IDENTIFIED BY '$dbPassword';
CREATE USER IF NOT EXISTS '$dbUser'@'127.0.0.1' IDENTIFIED BY '$dbPassword';
GRANT ALL PRIVILEGES ON acore_auth.* TO '$dbUser'@'localhost';
GRANT ALL PRIVILEGES ON acore_characters.* TO '$dbUser'@'localhost';
GRANT ALL PRIVILEGES ON acore_world.* TO '$dbUser'@'localhost';
GRANT ALL PRIVILEGES ON acore_auth.* TO '$dbUser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON acore_characters.* TO '$dbUser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON acore_world.* TO '$dbUser'@'127.0.0.1';
"@
Write-Host 'Enter MySQL root password once more to create the database and account:'
& $mysql '--protocol=tcp' '-h' '127.0.0.1' '-P' '3306' '-u' 'root' '-p' "--execute=$createSql"
if ($LASTEXITCODE -ne 0) {
    throw 'Database creation failed. Check MySQL permissions. Existing databases are not deleted automatically.'
}

New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root 'logs') | Out-Null

$auth = Join-Path $cfgDir 'authserver.conf'
$world = Join-Path $cfgDir 'worldserver.conf'
Copy-Item -LiteralPath "$auth.dist" -Destination $auth
Copy-Item -LiteralPath "$world.dist" -Destination $world
$authConnection = "127.0.0.1;3306;$dbUser;$dbPassword;acore_auth"
$worldConnection = "127.0.0.1;3306;$dbUser;$dbPassword;acore_world"
$charConnection = "127.0.0.1;3306;$dbUser;$dbPassword;acore_characters"

Set-ConfOption $auth 'LoginDatabaseInfo' ('"' + $authConnection + '"')
Set-ConfOption $world 'LoginDatabaseInfo' ('"' + $authConnection + '"')
Set-ConfOption $world 'WorldDatabaseInfo' ('"' + $worldConnection + '"')
Set-ConfOption $world 'CharacterDatabaseInfo' ('"' + $charConnection + '"')
Set-ConfOption $auth 'BindIP' '"127.0.0.1"'
Set-ConfOption $world 'BindIP' '"127.0.0.1"'
Set-ConfOption $world 'RealmID' '1'
Set-ConfOption $world 'DataDir' ('"' + (PathForConfig $dataDir) + '"')
Set-ConfOption $auth 'SourceDirectory' ('"' + (PathForConfig (Join-Path $root 'SQL_SOURCE')) + '"')
Set-ConfOption $world 'SourceDirectory' ('"' + (PathForConfig (Join-Path $root 'SQL_SOURCE')) + '"')
Set-ConfOption $auth 'MySQLExecutable' ('"' + (PathForConfig $mysql) + '"')
Set-ConfOption $world 'MySQLExecutable' ('"' + (PathForConfig $mysql) + '"')
Set-ConfOption $auth 'Updates.EnableDatabases' '1'
Set-ConfOption $world 'Updates.EnableDatabases' '7'
Set-ConfOption $auth 'Updates.AutoSetup' '1'
Set-ConfOption $world 'Updates.AutoSetup' '1'

$modDir = Join-Path $cfgDir 'modules'
if (Test-Path -LiteralPath $modDir) {
    Get-ChildItem -Path $modDir -Filter '*.conf.dist' -File | ForEach-Object {
        $target = $_.FullName.Substring(0, $_.FullName.Length - 5)
        if (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath $_.FullName -Destination $target }
    }
}
Write-Host ''
Write-Host 'Local server configuration created successfully.' -ForegroundColor Green
Write-Host 'MySQL data is stored locally. Keep your configs private: they contain the DB account password.'
Write-Host 'NEXT: Put client data in the Data folder (dbc, maps, vmaps, mmaps).'
Write-Host 'Then start START_SERVER.cmd. The first server launch will initialize SQL tables.'
Write-Host 'After the DB has been populated, run CUSTOM\APPLY_CUSTOM_ITEMS.cmd.'
Write-Host 'For an AH bot you still need to configure a dedicated game account and character.'
