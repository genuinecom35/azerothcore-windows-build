# AzerothCore WoW 3.3.5a — Custom Windows Build

Сборка игрового сервера AzerothCore для Windows x64 через GitHub Actions.

**Включено:** [mod-transmog](https://github.com/azerothcore/mod-transmog),
[mod-ah-bot](https://github.com/azerothcore/mod-ah-bot) и 3 демонстрационных кастомных предмета с переводом `ruRU`.

- [Инструкция на русском](custom/README_RU.md)
- [SQL: кастомные предметы + ruRU](custom/custom_items_ruRU.sql)
- [Импорт предметов для Windows](custom/install_custom_items.cmd)
- [Запуски сборки и файлы для скачивания](https://github.com/genuinecom35/azerothcore-windows-build/actions)

При успешной компиляции скачайте артефакт **AzerothCore-3.3.5a-Windows-x64-Custom** со страницы нужного запуска Actions.

**Примечание:** артефакт содержит собранные серверные файлы и `CUSTOM`, но MySQL-базы и игровые карты
настраиваются отдельно. Для интерфейса на русском нужен собственный WoW 3.3.5a клиент с локалью `ruRU`.
