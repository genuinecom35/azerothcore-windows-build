$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host 'Извлечение данных клиента WoW Legion 7.3.5 build 26972' -ForegroundColor Cyan
Write-Host 'Нужен ваш собственный совместимый клиент. Клиентские файлы в архив не входят.'
$ClientInput = Read-Host 'Полный путь к папке клиента (там должен быть Wow.exe)'
if (-not (Test-Path -LiteralPath $ClientInput)) { throw "Папка не найдена: $ClientInput" }
$Client = (Resolve-Path -LiteralPath $ClientInput).Path
if (-not (Test-Path -LiteralPath (Join-Path $Client 'Wow.exe'))) {
    throw 'В указанной папке не найден Wow.exe. Укажите корневую папку клиента 7.3.5 build 26972.'
}

$Tools = @('mapextractor.exe', 'vmap4extractor.exe', 'vmap4assembler.exe', 'mmaps_generator.exe')
foreach ($Tool in $Tools) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $Tool))) {
        throw "Не найден инструмент $Tool в папке сервера."
    }
}

Write-Host ''
Write-Host 'Важно: извлечение может занять много времени и потребовать десятки гигабайт свободного места.' -ForegroundColor Yellow
Write-Host 'Не закрывайте окно, пока все четыре этапа не завершатся.'
Push-Location $Client
try {
    Write-Host '[1/4] Извлечение DBC, карт и таблиц клиента...'
    & (Join-Path $Root 'mapextractor.exe')
    if ($LASTEXITCODE -ne 0) { throw "mapextractor завершился с кодом $LASTEXITCODE" }

    Write-Host '[2/4] Извлечение геометрии VMAP...'
    & (Join-Path $Root 'vmap4extractor.exe')
    if ($LASTEXITCODE -ne 0) { throw "vmap4extractor завершился с кодом $LASTEXITCODE" }

    Write-Host '[3/4] Сборка VMAP...'
    if (-not (Test-Path -LiteralPath (Join-Path $Client 'Buildings'))) {
        throw 'Папка Buildings не создана vmap4extractor.'
    }
    & (Join-Path $Root 'vmap4assembler.exe') 'Buildings' 'vmaps'
    if ($LASTEXITCODE -ne 0) { throw "vmap4assembler завершился с кодом $LASTEXITCODE" }

    Write-Host '[4/4] Генерация MMAP (может выполняться долго)...'
    & (Join-Path $Root 'mmaps_generator.exe')
    if ($LASTEXITCODE -ne 0) { throw "mmaps_generator завершился с кодом $LASTEXITCODE" }
}
finally {
    Pop-Location
}

$DataDir = Join-Path $Root 'ClientData'
New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
$RequiredFolders = @('dbc', 'maps', 'vmaps', 'mmaps', 'cameras', 'gt')
foreach ($Name in $RequiredFolders) {
    $Source = Join-Path $Client $Name
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "После извлечения отсутствует папка '$Name'. Проверьте клиент build 26972 и повторите этап извлечения."
    }
    $Destination = Join-Path $DataDir $Name
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
    Write-Host "Готово: ClientData\$Name"
}
Write-Host ''
Write-Host 'Данные скопированы в ClientData. Теперь можно запускать START_SERVER.cmd.' -ForegroundColor Green
