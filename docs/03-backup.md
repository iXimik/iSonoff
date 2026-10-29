# 03. Определение ESP8285 и двойной резервный дамп

**Это исторически воспроизведённая последовательность успешного эксперимента.** Использовались CH340, COM8, ESP8285N08, esptool 5.6.0 и Flash 1 МБ.

## 1. Перед подачей питания

- SONOFF **не подключён к сети 220 В**.
- RX/TX перекрёстно, GND общий, 3,3 В от подходящего источника.
- CH340 подключён к USB, найден актуальный COM.
- `miniterm` и другие приложения COM закрыты.

## 2. Войти в UART ROM bootloader

1. Отключить **низковольтное** питание 3,3 В SONOFF.
2. **Зажать штатную кнопку SONOFF** (обычно тянет GPIO0 к GND).
3. Удерживая кнопку, подать 3,3 В на SONOFF.
4. Через 1–2 секунды отпустить кнопку. **Не отключать питание.**
5. В PowerShell запускать команды `esptool`.

При питании от проверенного адаптера CH340 подача 3,3 В может происходить при подключении адаптера к USB; в других схемах отдельный источник включается отдельно.

## 3. Определить чип, не меняя Flash

```powershell
$Port = "COM8"   # заменить при необходимости
py -m esptool --chip esp8266 --port $Port --baud 115200 --before no-reset --after no-reset flash-id
```

Подтверждённый вывод реальной платы (идентификатор устройства не публикуется):

```text
Connected to ESP8266 on COM8:
Chip type: ESP8285N08
Features: Wi-Fi, 160MHz, Embedded Flash
Crystal frequency: 26MHz
Stub flasher running.
Detected flash size: 1MB
Staying in bootloader.
```

Под `--chip esp8266` esptool понимает и **ESP8285** — это ожидаемо. Для другого чипа / объёма Flash **не копировать наугад** размер 0x100000.

## 4. Первая копия

```powershell
$BackupDir = Join-Path $env:USERPROFILE "Downloads\SONOFF_Backup"
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

py -m esptool --chip esp8266 --port $Port --baud 115200 --before no-reset --after no-reset read-flash 0x0 0x100000 "$BackupDir\sonoff_original.bin"
if ($LASTEXITCODE -ne 0) { throw "Первое считывание не удалось" }

(Get-Item "$BackupDir\sonoff_original.bin").Length
```

Для Flash 1 МБ корректный размер **1 048 576 байт**. Успех чтения ещё не доказывает, что заводская прошивка ранее работала, только что сохранено содержимое памяти.

## 5. Вторая копия и сверка SHA-256

При сохранении режима загрузчика (`--after no-reset`) питание между командами не выключали. При переподключении выполнить вход в загрузчик заново.

```powershell
py -m esptool --chip esp8266 --port $Port --baud 115200 --before no-reset --after no-reset read-flash 0x0 0x100000 "$BackupDir\sonoff_original_check.bin"
if ($LASTEXITCODE -ne 0) { throw "Второе считывание не удалось" }

$a = Get-Item "$BackupDir\sonoff_original.bin"
$b = Get-Item "$BackupDir\sonoff_original_check.bin"
$ha = (Get-FileHash $a.FullName -Algorithm SHA256).Hash
$hb = (Get-FileHash $b.FullName -Algorithm SHA256).Hash

if ($a.Length -ne 1048576 -or $b.Length -ne 1048576 -or $ha -ne $hb) {
    throw "Дампы не совпадают!"
}
Write-Host "BACKUP VERIFIED - IDENTICAL!" -ForegroundColor Green
```

**Фактический результат:** 2 × 1 048 576 байт; хеши совпали; `BACKUP VERIFIED - IDENTICAL!`.

Для дополнительной проверки хранящегося локально дампа можно использовать сохранённую ранее SHA-256, но не нужно публиковать сам BIN.

## 6. Хранение и восстановление

Храните файлы на двух независимых носителях. Дампы могут содержать Wi-Fi пароли и другие конфиденциальные настройки. **В публичный GitHub не отправлять**.

Обратная запись полного дампа — отдельная потенциально разрушительная процедура. Её не следует выполнять без проверки модели, корректного BIN, электробезопасности и последствий для заводской конфигурации.

### Скрипт вместо ручного ввода

```powershell
.\scripts\Backup-Sonoff.ps1 -Port COM8
```

Скрипт делает два чтения и проверяет совпадение, но не способен самостоятельно перевести плату в bootloader или проверить электробезопасность.

Следующий этап: [прошивка Tasmota](04-flashing.md).
