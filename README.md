# Warcraft III FPS Setup

**[English](#english) | [Русский](#russian)**

<a id="english"></a>

## English

An FPS Unlocker installer for **Warcraft III 1.26a** (Reign of Chaos and The Frozen Throne).
Helps remove the internal frame rate limit of approximately 64 FPS and configure the game for a high refresh rate monitor.

**Installer developer: [Sw1ziy](https://github.com/Sw1ziy).**

### Installation

1. Click **Code → Download ZIP** and extract the entire archive.
2. Close Warcraft III.
3. Double-click **Install.cmd**.
4. Select the game folder containing `war3.exe` and click **Установить (Install)**.
5. Launch Warcraft using your usual shortcut.

The display settings checkbox applies the current resolution and refresh rate of your **primary Windows monitor**.
If you play on another monitor or want to keep your existing resolution, uncheck it: the unlocker will still be installed.
The installer preserves your saved games, campaign progress, and replays.

To enable the built-in FPS counter during a match, press Enter, type `/fps`, and press Enter again.
Actual FPS depends on your hardware, map, and scene. The unlocker may bypass the game's `maxfps` setting,
so the counter may show a frame rate higher than your monitor's refresh rate.

### Restoring the previous settings

Run **Install.cmd** again, select the same game folder, and click **Восстановить (Restore)**.
The installer restores your previous video settings and the previous unlocker file, if one was already present.
If no unlocker was present before installation, the installed module is removed.

The original state is stored in the `.warcraft-fps-setup` folder inside the game folder. Keep it until you restore.
Reinstalling preserves the original backup.
Video settings are shared across Warcraft III installations within the same Windows user account;
the unlocker is installed only in the selected folder.

### Requirements and limitations

- Windows 10/11 with Windows PowerShell 5.1; other systems have not been tested.
- An existing Warcraft III **1.26a / 1.26.0.6401** installation. Other versions are rejected before any changes.
- Internet access to download the module from its author's GitHub, and write access to the selected game folder.
- Intended for single-player use. The unlocker author warns of a possible conflict with iCCup's anti-cheat.
- If access is denied, use a game folder you can write to. The installer does not request administrator privileges automatically.
- The installer interface is currently in Russian. The relevant button names are translated in the steps above.

### Third-party unlocker

This installer uses **[FPS Unlocker](https://github.com/UnryzeC/WC3_FPSUnlocker)**,
a third-party component by **UnryzeC (Unryze)**. It is a separate project developed by its own author.

The installer downloads `FPSUnlocker.mix` version **1.1.0.5** directly from
[the author's release](https://github.com/UnryzeC/WC3_FPSUnlocker/releases/tag/v1.1.0.5)
and verifies its SHA-256 before installation:

```text
f3b497d961a5d4e2a8a089773fde99fae2e020a8729f9a37d6f53a8216e9405c
```

This repository contains no Warcraft III game files, saved games, game keys, or copy of the unlocker.
The MIT license covers only this installer's code and documentation, not the game or the third-party module.

### Checking the source

Run these commands in PowerShell from the project folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Test-Installer.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File Setup.ps1 -CheckOnly
```

Tests use a separate temporary directory and a separate registry key.
They preserve your actual game settings and saved games.

[Back to language selection](#warcraft-iii-fps-setup)

---

<a id="russian"></a>

## Русский

Установщик FPS Unlocker для **Warcraft III 1.26a** (Reign of Chaos и The Frozen Throne).
Помогает убрать внутреннее ограничение около 64 FPS и настроить игру под монитор с высокой частотой обновления.

**Разработчик установщика: [Sw1ziy](https://github.com/Sw1ziy).**

### Как установить

1. Нажмите **Code → Download ZIP** и распакуйте архив целиком.
2. Закройте Warcraft III.
3. Запустите **Install.cmd** двойным щелчком.
4. Укажите папку игры с файлом `war3.exe` и нажмите **Установить**.
5. Запустите Warcraft привычным ярлыком.

Галочка настройки экрана выставляет текущее разрешение и частоту **основного монитора Windows**.
Если играете на другом мониторе или хотите сохранить прежнее разрешение, снимите её: анлокер всё равно установится.
Сохранения, кампании и повторы установщик не меняет.

Чтобы включить встроенный счётчик кадров, в матче нажмите Enter, введите `/fps` и снова нажмите Enter.
FPS зависит от компьютера, карты и сцены. Анлокер может обходить штатный лимит `maxfps`,
поэтому счётчик способен показывать больше кадров, чем частота монитора.

### Как отменить изменения

Снова запустите **Install.cmd**, укажите ту же папку игры и нажмите **Восстановить**.
Установщик вернёт прежние видеонастройки и прежний файл анлокера, если он уже был установлен.
Если анлокера не было, установленный модуль будет удалён.

Исходное состояние хранится в папке `.warcraft-fps-setup` внутри игры. Сохраните её до восстановления.
Повторная установка сохраняет первоначальную резервную копию.
Видеонастройки общие для копий Warcraft III в одной учётной записи Windows;
анлокер устанавливается только в выбранную папку.

### Требования и ограничения

- Windows 10/11 с Windows PowerShell 5.1; на других системах установщик не проверялся.
- Уже установленный Warcraft III **1.26a / 1.26.0.6401**. Другие версии отклоняются до изменений.
- Интернет для скачивания модуля с GitHub автора и право записи в выбранную папку игры.
- Установщик предназначен для одиночной игры. Автор анлокера предупреждает о возможном конфликте с античитом iCCup.
- При ошибке доступа используйте доступную для записи папку игры. Установщик сам не запрашивает права администратора.
- Интерфейс установщика сейчас доступен на русском языке.

### Откуда берётся анлокер

Используется сторонний **[FPS Unlocker](https://github.com/UnryzeC/WC3_FPSUnlocker)**,
автор — **UnryzeC (Unryze)**. Это отдельный проект, не разработка Sw1ziy.

Установщик скачивает `FPSUnlocker.mix` версии **1.1.0.5** напрямую из
[релиза автора](https://github.com/UnryzeC/WC3_FPSUnlocker/releases/tag/v1.1.0.5)
и проверяет SHA-256 перед установкой:

```text
f3b497d961a5d4e2a8a089773fde99fae2e020a8729f9a37d6f53a8216e9405c
```

В этом репозитории нет файлов Warcraft III, сохранений, ключей игры или копии анлокера.
Лицензия MIT относится только к коду и документации этого установщика, не к игре или стороннему модулю.

### Проверка исходников

В PowerShell из папки проекта:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Test-Installer.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File Setup.ps1 -CheckOnly
```

Тесты используют отдельный временный каталог и отдельную ветку реестра.
Реальные настройки и сохранения игры при тестировании не изменяются.

[К выбору языка](#warcraft-iii-fps-setup)
