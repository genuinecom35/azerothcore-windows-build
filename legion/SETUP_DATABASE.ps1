$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$SqlRoot = Join-Path $Root 'sql'
$DatabaseNames = @('legion735_auth', 'legion735_characters', 'legion735_world', 'legion735_hotfixes')

Write-Host ''
Write-Host 'WoW Legion 7.3.5 - создание отдельных баз данных' -ForegroundColor Cyan
Write-Host 'Существующие базы auth/characters/world/hotfixes не используются и не изменяются.' -ForegroundColor Green
Write-Host ''

$MysqlCandidates = @(
    (Join-Path $Root 'mysql\bin\mysql.exe'),
    'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe',
    'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe',
    'C:\Program Files\MySQL\MySQL Server 8.1\bin\mysql.exe'
)
$Mysql = $null
$Command = Get-Command mysql.exe -ErrorAction SilentlyContinue
if ($Command) { $Mysql = $Command.Source }
if (-not $Mysql) {
    foreach ($Candidate in $MysqlCandidates) {
        if (Test-Path -LiteralPath $Candidate) { $Mysql = $Candidate; break }
    }
}
if (-not $Mysql) {
    $Mysql = Read-Host 'Введите полный путь к mysql.exe'
}
if (-not (Test-Path -LiteralPath $Mysql)) {
    throw "mysql.exe не найден: $Mysql"
}
$Mysql = (Resolve-Path -LiteralPath $Mysql).Path

$HostName = Read-Host 'MySQL host [127.0.0.1]'
if ([string]::IsNullOrWhiteSpace($HostName)) { $HostName = '127.0.0.1' }
$Port = Read-Host 'MySQL port [3306]'
if ([string]::IsNullOrWhiteSpace($Port)) { $Port = '3306' }
$AdminUser = Read-Host 'MySQL admin user [root]'
if ([string]::IsNullOrWhiteSpace($AdminUser)) { $AdminUser = 'root' }
$SecurePassword = Read-Host 'Пароль администратора MySQL (Enter, если пароля нет)' -AsSecureString
$PasswordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
try {
    $AdminPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($PasswordPtr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PasswordPtr)
}

$TempConfig = Join-Path $env:TEMP ("legion735-mysql-" + [Guid]::NewGuid().ToString('N') + '.ini')
$DbUser = 'legion735_' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$DbPassword = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$Completed = $false

function Set-QuotedConfigValue([string]$Text, [string]$Key, [string]$Value) {
    $Pattern = '(?m)^\s*' + [regex]::Escape($Key) + '\s*=.*$'
    $Replacement = $Key + ' = "' + $Value + '"'
    $Updated = ([regex]::new($Pattern)).Replace($Text, $Replacement, 1)
    if ($Updated -eq $Text) { throw "Не найден параметр $Key в конфигурации." }
    return $Updated
}

function Set-RawConfigValue([string]$Text, [string]$Key, [string]$Value) {
    $Pattern = '(?m)^\s*' + [regex]::Escape($Key) + '\s*=.*$'
    $Replacement = $Key + ' = ' + $Value
    $Updated = ([regex]::new($Pattern)).Replace($Text, $Replacement, 1)
    if ($Updated -eq $Text) { throw "Не найден параметр $Key в конфигурации." }
    return $Updated
}

function Import-SqlFile([string]$Database, [string]$FilePath, [string]$MysqlPath, [string]$TempIni) {
    if (-not (Test-Path -LiteralPath $FilePath)) { throw "SQL-файл не найден: $FilePath" }
    Write-Host ("Импорт: {0} -> {1}" -f (Split-Path -Leaf $FilePath), $Database) -ForegroundColor Yellow
    $ResolvedFile = (Resolve-Path -LiteralPath $FilePath).Path
    $Arguments = @('--defaults-extra-file="' + $TempIni + '"', '--default-character-set=utf8mb4', $Database)
    $Process = Start-Process -FilePath $MysqlPath -ArgumentList $Arguments -RedirectStandardInput $ResolvedFile -NoNewWindow -Wait -PassThru
    if ($Process.ExitCode -ne 0) { throw "Импорт SQL завершился с кодом $($Process.ExitCode): $FilePath" }
}

try {
    $EscapedPassword = $AdminPassword.Replace('\', '\\').Replace('"', '\"')
    @(
        '[client]',
        "host=$HostName",
        "port=$Port",
        "user=$AdminUser",
        ('password="' + $EscapedPassword + '"'),
        'default-character-set=utf8mb4'
    ) | Set-Content -LiteralPath $TempConfig -Encoding ASCII

    $MysqlOptions = @("--defaults-extra-file=$TempConfig", '--default-character-set=utf8mb4')
    $DatabaseList = "'" + ($DatabaseNames -join "','") + "'"
    $Existing = & $Mysql @MysqlOptions -N -B -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME IN ($DatabaseList);"
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось подключиться к MySQL. Проверьте адрес, порт, имя пользователя и пароль.' }
    if ($Existing) {
        throw ("Базы {0} уже существуют. Скрипт остановлен, чтобы не перезаписать данные. Сначала сделайте резервную копию и отдельно разберите только эти базы Legion." -f ($Existing -join ', '))
    }

    $CreateSql = @"
CREATE DATABASE legion735_auth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE legion735_characters CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE legion735_world CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE legion735_hotfixes CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DbUser'@'127.0.0.1' IDENTIFIED BY '$DbPassword';
GRANT ALL PRIVILEGES ON legion735_auth.* TO '$DbUser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON legion735_characters.* TO '$DbUser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON legion735_world.* TO '$DbUser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON legion735_hotfixes.* TO '$DbUser'@'127.0.0.1';
FLUSH PRIVILEGES;
"@
    & $Mysql @MysqlOptions -e $CreateSql
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось создать базы Legion и отдельного пользователя MySQL.' }

    Import-SqlFile 'legion735_auth' (Join-Path $SqlRoot 'base\auth_database.sql') $Mysql $TempConfig
    Import-SqlFile 'legion735_characters' (Join-Path $SqlRoot 'base\characters_database.sql') $Mysql $TempConfig

    $WorldFiles = @(Get-ChildItem -LiteralPath (Join-Path $SqlRoot 'base\world') -Filter 'world_database_*.sql' -File | Sort-Object Name)
    if ($WorldFiles.Count -eq 0) { throw 'Не найдены базовые SQL-файлы world.' }
    foreach ($File in $WorldFiles) {
        Import-SqlFile 'legion735_world' $File.FullName $Mysql $TempConfig
    }

    $HotfixFiles = @(Get-ChildItem -LiteralPath (Join-Path $SqlRoot 'base\hotfixes') -Filter 'hotfixes_database_*.sql' -File | Sort-Object Name)
    if ($HotfixFiles.Count -eq 0) { throw 'Не найдены базовые SQL-файлы hotfixes.' }
    foreach ($File in $HotfixFiles) {
        Import-SqlFile 'legion735_hotfixes' $File.FullName $Mysql $TempConfig
    }

    $MysqlConfigPath = $Mysql.Replace('\', '/')
    $Bnet = Get-Content -LiteralPath (Join-Path $Root 'bnetserver.conf.dist') -Raw
    $Bnet = Set-QuotedConfigValue $Bnet 'LoginDatabaseInfo' "$HostName;$Port;$DbUser;$DbPassword;legion735_auth"
    $Bnet = Set-QuotedConfigValue $Bnet 'SourceDirectory' '.'
    $Bnet = Set-QuotedConfigValue $Bnet 'MySQLExecutable' $MysqlConfigPath
    [IO.File]::WriteAllText((Join-Path $Root 'bnetserver.conf'), $Bnet, [Text.UTF8Encoding]::new($false))

    $World = Get-Content -LiteralPath (Join-Path $Root 'worldserver.conf.dist') -Raw
    $World = Set-QuotedConfigValue $World 'LoginDatabaseInfo' "$HostName;$Port;$DbUser;$DbPassword;legion735_auth"
    $World = Set-QuotedConfigValue $World 'CharacterDatabaseInfo' "$HostName;$Port;$DbUser;$DbPassword;legion735_characters"
    $World = Set-QuotedConfigValue $World 'HotfixDatabaseInfo' "$HostName;$Port;$DbUser;$DbPassword;legion735_hotfixes"
    $World = Set-QuotedConfigValue $World 'WorldDatabaseInfo' "$HostName;$Port;$DbUser;$DbPassword;legion735_world"
    $World = Set-QuotedConfigValue $World 'DataDir' './ClientData'
    $World = Set-QuotedConfigValue $World 'SourceDirectory' '.'
    $World = Set-QuotedConfigValue $World 'MySQLExecutable' $MysqlConfigPath
    $World = Set-RawConfigValue $World 'MaxPlayerLevel' '110'
    $World = Set-RawConfigValue $World 'DBC.Locale' '8'
    $World = Set-RawConfigValue $World 'Rate.XP.Kill' '1'
    $World = Set-RawConfigValue $World 'Rate.XP.Quest' '1'
    $World = Set-RawConfigValue $World 'Rate.XP.Explore' '1'
    $World = Set-RawConfigValue $World 'Rate.XP.Gathering' '1'
    [IO.File]::WriteAllText((Join-Path $Root 'worldserver.conf'), $World, [Text.UTF8Encoding]::new($false))

    $Completed = $true
    Write-Host ''
    Write-Host 'Базовые базы данных импортированы.' -ForegroundColor Green
    Write-Host 'При первом запуске worldserver применит SQL-обновления из папки sql/updates.' -ForegroundColor Green
    Write-Host 'Настройки подключения сохранены в bnetserver.conf и worldserver.conf.' -ForegroundColor Green
    Write-Host 'Базы текущего WoW 3.3.5a не затрагивались.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $TempConfig) { Remove-Item -LiteralPath $TempConfig -Force -ErrorAction SilentlyContinue }
    $AdminPassword = $null
    $DbPassword = $null
}

if (-not $Completed) { exit 1 }
