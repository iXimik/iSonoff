# 02. Windows, USB-UART и COM-порты

В эксперименте работали Windows PowerShell и Python; отдельной Arduino IDE не требовалось.

## 1. Установка Python и esptool

В PowerShell:

```powershell
py --version
py -m pip install --upgrade esptool pyserial
py -m esptool version
```

Успешная версия в эксперименте: **esptool 5.6.0**. У этой версии имена подкоманд с дефисом: `flash-id`, `read-flash`, `erase-flash`, `write-flash`, `image-info`.

## 2. Драйверы

В «Диспетчере устройств» → «Порты (COM и LPT)»:

- `USB-SERIAL CH340 (COMx)` — адаптер CH340.
- `Silicon Labs CP210x USB to UART Bridge (COMx)` — адаптер CP2102.
- Жёлтый треугольник в «Другие устройства» означает проблему драйвера.

В этом эксперименте CP2102 сначала отображался с ошибкой. Для CP210x был установлен пакет `silabser.inf`, затем Windows определила COM3. Позднее для SONOFF использовали **другой адаптер CH340**, номера COM10, COM8. Порты меняются после переподключения.

Официальный источник CP210x: https://www.silabs.com/software-and-tools/usb-to-uart-bridge-vcp-drivers . CH340: драйвер WCH, полученный от надёжного поставщика адаптера/производителя, а не случайного сайта.

### Пример установки уже скачанного пакета CP210x

В PowerShell **от имени администратора**, после распаковки официального архива и проверки INF:

```powershell
$DriverDir = Join-Path $env:USERPROFILE "Downloads\CP210x_Driver"
Get-ChildItem $DriverDir -Recurse -Filter *.inf
pnputil /add-driver "$DriverDir\*.inf" /subdirs /install
```

`pnputil` не должен использоваться для нераспакованного архива или неизвестных файлов.

## 3. Найти текущий COM

```powershell
py -m serial.tools.list_ports -v
[System.IO.Ports.SerialPort]::GetPortNames()
Get-PnpDevice -Class Ports | Select-Object FriendlyName,Status
```

`Get-CimInstance Win32_SerialPort` иногда не показывает USB-UART, даже когда `miniterm` успешно открывает порт. В эксперименте так случилось с CH340. При расхождении ориентируйтесь на «Диспетчер устройств» и `py -m serial.tools.list_ports -v`.

## 4. Loopback Test

Проверяет только адаптер. **SONOFF отсоединён**, никаких проводов к нему. При отключённом USB соединить **TXD ↔ RXD** адаптера, затем подключить USB:

```powershell
$Port = "COM8"  # актуальный COM
py -c "import serial; s=serial.Serial('$Port',115200,timeout=2); s.reset_input_buffer(); s.write(b'GOSHA_LOOPBACK_123'); print('Received:',s.read(18)); s.close()"
```

Ожидается:

```text
Received: b'GOSHA_LOOPBACK_123'
```

**Успешный результат был получен в нашем эксперименте.** Ответ `b''` означает, что эхо не пришло — проверить перемычку, маркировку TXD/RXD, настройки напряжения/`VCC` (зависят от модели адаптера). Это не обязательно неисправность USB-UART.

По завершении **отключить USB и убрать перемычку TXD ↔ RXD** перед подключением SONOFF.

## 5. Монитор UART

```powershell
py -m serial.tools.miniterm COM8 115200 --dtr 0 --rts 0
```

Закрытие: `Ctrl+]`. Одновременно два приложения к одному COM обычно подключить нельзя. Запуск Tasmota логируется на 115200 бод; сообщения ROM ESP8266/ESP8285 обычно появляются на 74880 бод, в отличие от ESP32.

Если PowerShell перешёл в `[DBG]` из-за PSReadLine, введите `q`, затем откройте чистую сессию `powershell.exe -NoProfile`. Длинные многострочные фрагменты удобнее сохранять как `.ps1`.

## 6. Проверки перед работой с SONOFF

- Адаптер виден как COM.
- Loopback Test пройден.
- RXD–TXD перемычка снята.
- Уровень TXD относительно GND близок к 3,3 В, не 5 В.
- Известна допустимая нагрузка источника 3V3.
- SONOFF физически отсоединён от сети AC.

Далее: [вход в загрузчик и backup](03-backup.md).
