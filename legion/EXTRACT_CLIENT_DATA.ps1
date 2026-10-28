param(
    [switch]$ResumeFromVmaps
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host 'Извлечение данных клиента WoW Legion 7.3.5 build 26972' -ForegroundColor Cyan
$ClientInput = Read-Host 'Полный путь к папке клиента (где лежит Wow.exe)'
if (-not (Test-Path -LiteralPath $ClientInput -PathType Container)) {
    throw "Папка не найдена: $ClientInput"
}
$Client = (Resolve-Path -LiteralPath $ClientInput).Path
$ClientExe = Join-Path $Client 'Wow.exe'
if (-not (Test-Path -LiteralPath $ClientExe -PathType Leaf)) {
    throw 'В указанной папке не найден Wow.exe.'
}

$ClientVersion = (Get-Item -LiteralPath $ClientExe).VersionInfo.FileVersion
if ($ClientVersion -notmatch '(^|\D)26972($|\D)') {
    throw "Несовместимый клиент: Wow.exe имеет версию '$ClientVersion', требуется 7.3.5.26972. Версия 26124 не подходит."
}

if (-not (Test-Path -LiteralPath (Join-Path $Client 'Data') -PathType Container)) {
    throw 'В папке клиента отсутствует Data.'
}
if (-not $ResumeFromVmaps -and
    -not (Test-Path -LiteralPath (Join-Path $Client '.build.info') -PathType Leaf) -and
    -not (Test-Path -LiteralPath (Join-Path $Client '.build.db') -PathType Leaf)) {
    throw 'Не найден .build.info или .build.db. Экстракторы не смогут открыть CASC.'
}

$Tools = @('mapextractor.exe', 'vmap4extractor.exe', 'vmap4assembler.exe', 'mmaps_generator.exe')
foreach ($Tool in $Tools) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $Tool) -PathType Leaf)) {
        throw "Не найден инструмент $Tool в папке сервера."
    }
}

$OutputRoot = Join-Path $Client 'ClientData'
$Buildings = Join-Path $OutputRoot 'Buildings'
$DirBin = Join-Path $Buildings 'dir_bin'

function Assert-ExtractedFile([string]$Directory, [string]$Filter, [string]$Description, [bool]$Recurse = $false) {
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        throw "Отсутствует папка $Directory ($Description)."
    }
    $Args = @{
        LiteralPath = $Directory
        Filter = $Filter
        File = $true
        ErrorAction = 'Stop'
    }
    if ($Recurse) { $Args.Recurse = $true }
    if (-not (Get-ChildItem @Args | Select-Object -First 1)) {
        throw "Не найдены файлы '$Filter' в $Directory ($Description)."
    }
}

Write-Host ''
Write-Host "Клиент: $Client"
Write-Host "Версия Wow.exe: $ClientVersion"
Write-Host "Рабочие данные экстракторов: $OutputRoot"
Write-Host "Режим продолжения после VMAP: $ResumeFromVmaps"
Write-Host 'Не закрывайте окна экстракторов до завершения обработки.' -ForegroundColor Yellow

Push-Location $Client
try {
    if ($ResumeFromVmaps) {
        Write-Host '[1/4] Пропуск: MAP/DBC уже извлечены.'
        Assert-ExtractedFile (Join-Path $OutputRoot 'maps') '*.map' 'карты'
        Assert-ExtractedFile (Join-Path $OutputRoot 'dbc') '*.db2' 'таблицы' $true
        if (-not (Test-Path -LiteralPath $DirBin -PathType Leaf)) {
            throw "Для продолжения отсутствует $DirBin. Сначала проверьте завершение vmap4extractor."
        }
        Assert-ExtractedFile $Buildings '*' 'модели VMAP'
        Write-Host '[2/4] Пропуск: VMAP-модели уже извлечены.'
    }
    else {
        Write-Host '[1/4] Извлечение DBC, карт и таблиц клиента...'
        & (Join-Path $Root 'mapextractor.exe')
        if ($LASTEXITCODE -ne 0) { throw "mapextractor завершился с кодом $LASTEXITCODE" }
        Assert-ExtractedFile (Join-Path $OutputRoot 'maps') '*.map' 'карты'
        Assert-ExtractedFile (Join-Path $OutputRoot 'dbc') '*.db2' 'таблицы' $true

        Write-Host '[2/4] Извлечение геометрии VMAP...'
        & (Join-Path $Root 'vmap4extractor.exe')
        if ($LASTEXITCODE -ne 0) { throw "vmap4extractor завершился с кодом $LASTEXITCODE" }
        if (-not (Test-Path -LiteralPath $DirBin -PathType Leaf)) {
            throw "vmap4extractor не создал $DirBin. Проверьте вывод экстрактора."
        }
    }

    Write-Host '[3/4] Сборка VMAP...'
    & (Join-Path $Root 'vmap4assembler.exe') 'ClientData/Buildings' 'ClientData/vmaps'
    if ($LASTEXITCODE -ne 0) { throw "vmap4assembler завершился с кодом $LASTEXITCODE" }
    Assert-ExtractedFile (Join-Path $OutputRoot 'vmaps') '*.vmtree' 'собранные VMAP'

    Write-Host '[4/4] Генерация MMAP (может выполняться долго)...'
    & (Join-Path $Root 'mmaps_generator.exe')
    if ($LASTEXITCODE -ne 0) { throw "mmaps_generator завершился с кодом $LASTEXITCODE" }
    Assert-ExtractedFile (Join-Path $OutputRoot 'mmaps') '*.mmap' 'навигационные MMAP'
}
finally {
    Pop-Location
}

$DataDir = Join-Path $Root 'ClientData'
New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
$RequiredFolders = @('dbc', 'maps', 'vmaps', 'mmaps', 'cameras', 'gt')
foreach ($Name in $RequiredFolders) {
    $Source = Join-Path $OutputRoot $Name
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "После извлечения отсутствует папка '$Source'."
    }
    $Destination = Join-Path $DataDir $Name
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Force |
        Copy-Item -Destination $Destination -Recurse -Force
    Write-Host "Готово: ClientData\$Name"
}

Write-Host ''
Write-Host 'Данные скопированы в серверную папку ClientData. Теперь можно запускать START_SERVER.cmd.' -ForegroundColor Green
