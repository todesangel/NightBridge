# NightBridge (base skeleton)

Базовая структура файлов для профилей запуска zapret/winws на Windows.

## Зависимости

- **WinDivert** (установленный драйвер/библиотеки)
- **Бинарники zapret/winws** (доступны локально, путь указывается в `.bat`)
- **PowerShell 5+** (для `test zapret.ps1` и вспомогательных задач)
- **Права администратора** (запуск `.bat`/`winws` и сетевые операции)

## Структура

- `general.bat`
- `general-ALT.bat` ... `general-ALT11.bat`
- `general-FAKE-TLS.bat` (+ дополнительные варианты `general-FAKE-TLS2.bat`, `general-FAKE-TLS3.bat`)
- `general-SIMPLE-FAKE.bat`
- `service.bat`
- `test zapret.ps1`
- `lists/` (списки доменов)
- `ipset/` (списки подсетей)
