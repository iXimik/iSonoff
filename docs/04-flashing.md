# 04. Установка Tasmota 16.0.0 RU на ESP8285N08

**Переходить сюда только после двух успешно сверенных резервных копий** (`docs/03-backup.md`). Стирание Flash уничтожит текущую заводскую прошивку и настройки на устройстве. Никаких контактов к сети AC одновременно с UART.

## 1. Получить официальный BIN

В успешном эксперименте 29.10.2026:

```powershell
$Firmware = Join-Path $env:USERPROFILE "Downloads\tasmota-RU.bin"
Invoke-WebRequest -Uri "https://ota.tasmota.com/tasmota/release/tasmota-RU.bin" -OutFile $Firmware
Get-Item $Firmware | Select-Object FullName,Length
```

**Фактический размер тогда:** 672 448 байт. Содержимое `release/` может меняться: у новой версии размер может быть другим. Для точной исторической воспроизводимости проверять версию и SHA-256 релиза и хранить отдельно локальную копию. **Не коммитить прошивки в репозиторий.**

## 2. Проверить ESP8266 image header

```powershell
py -m esptool --chip esp8266 image-info $Firmware
```

У проверенного BIN:

```text
Image size: 672448 bytes
Flash size: 1MB
Flash freq: 40m
Flash mode: DOUT
Checksum: 0xb0 (valid)
```

`image-info` проверяет структуру и внутреннюю контрольную сумму; это **не** криптографическая проверка издателя. Скачивайте BIN только из официального источника.

## 3. Подготовить режим загрузчика

1. Убедиться, что дампы находятся вне репозитория.
2. Отключить низковольтное питание SONOFF.
3. Удерживать штатную кнопку SONOFF.
4. Подать стабильные **3,3 В**, затем отпустить кнопку.
5. Оставить питание включённым, закрыть `miniterm`.
6. Проверить связь необязательной командой `flash-id`.

## 4. Стереть Flash

**НЕОБРАТИМО ДЛЯ ТЕКУЩЕГО СОДЕРЖИМОГО УСТРОЙСТВА.**

```powershell
$Port = "COM8"  # текущий номер USB-UART
py -m esptool --chip esp8266 --port $Port --baud 115200 --before no-reset --after no-reset erase-flash
if ($LASTEXITCODE -ne 0) { throw "Стирание не удалось. НЕ продолжать." }
```

Получено в реальном эксперименте: `Flash memory erased successfully in 2.5 seconds.`

## 5. Записать проверенный BIN

Не выключать низковольтное питание, если esptool сообщает `Staying in bootloader`:

```powershell
py -m esptool --chip esp8266 --port $Port --baud 115200 --before no-reset --after no-reset write-flash --flash-mode dout --flash-size 1MB 0x0 $Firmware
if ($LASTEXITCODE -ne 0) { throw "Прошивка не записана!" }
```

Получено в реальном эксперименте:

```text
Wrote 672448 bytes (479629 compressed) ...
Hash of data verified.
Staying in bootloader.
```

**`Hash of data verified` — подтверждение успешной записи, а не тест работы реле или Wi-Fi.**

## 6. Перезапуск в штатный режим

Отключить низковольтное питание полностью. Затем подать стабильные 3,3 В **без удержания кнопки GPIO0**. Если мощность адаптера недостаточна для Wi-Fi, сначала использовать подходящий безопасный внешний источник.

Веб-интерфейс проверять только после полного отсоединения UART-проводов и безопасной сборки устройства, если используется штатное сетевое питание.

## 7. Скрипт с проверками

```powershell
.\scripts\Flash-Tasmota.ps1 -Port COM8 -Firmware "$env:USERPROFILE\Downloads\tasmota-RU.bin"
```

По умолчанию **только предварительная проверка**. Для реального стирания и записи нужен параметр `-IUnderstandThisErasesFlash` и локально сохранённые совпадающие резервные копии. Подробности в самом скрипте.

Далее: [первый запуск](05-first-boot.md).
