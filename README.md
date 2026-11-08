# Warcraft III FPS Setup

**[English](#english) | [Русский](#russian)**

<a id="english"></a>

## English

An FPS Unlocker and optional W3TrueWidescreen installer for **Warcraft III 1.26a** (Reign of Chaos and The Frozen Throne).
Helps remove the internal frame rate limit of approximately 64 FPS, correct stretched game-world proportions,
and configure the game for a high refresh rate monitor.

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

### Widescreen and HUD options

**Widescreen correction and the full-width HUD are enabled by default.**

| Installer option | Result |
| --- | --- |
| **Исправить растяжение игрового мира** (Correct game-world stretching) | Installs W3TrueWidescreen to correct world proportions and the field of view on widescreen monitors. |
| **HUD на всю ширину экрана** (Full-width HUD) | Stretches the bottom panel across the screen while keeping the game world unstretched. |
| Full-width HUD unchecked | Keeps the interface's original proportions, with a narrower panel in the center. |
| Widescreen correction unchecked | Skips widescreen installation; FPS Unlocker is still installed. |

Unchecking an option skips that component on this run; it does not remove an already installed patch. Use **Восстановить (Restore)** to undo installation.
The preset keeps the original camera distance and UI size. W3TrueWidescreen's own FPS patch is disabled
to leave FPS handling to FPS Unlocker. Optional movie codecs, HDR hooks, and extra keyboard shortcuts are not enabled.
Widescreen correction requires the game's default **Direct3D** renderer; launch shortcuts using `-opengl` are not supported.

To enable the built-in FPS counter during a match, press Enter, type `/fps`, and press Enter again.
Actual FPS depends on your hardware, map, and scene. The unlocker may bypass the game's `maxfps` setting,
so the counter may show a frame rate higher than your monitor's refresh rate.

### Restoring the previous settings

Run **Install.cmd** again, select the same game folder, and click **Восстановить (Restore)**.
The installer restores your previous video settings and previous versions of the files it installed, if they were already present.
Files newly added by the installer are removed. This includes W3TrueWidescreen when installed through this tool.
An existing manual widescreen installation is backed up before replacement and restored on rollback.
Any manual edits to the installed widescreen configuration are also archived before rollback.

The original state is stored in the `.warcraft-fps-setup` folder inside the game folder. Keep it until you restore.
Reinstalling preserves the original backup.
Video settings are shared across Warcraft III installations within the same Windows user account;
the unlocker is installed only in the selected folder.

### Requirements and limitations

- Windows 10/11 with Windows PowerShell 5.1; other systems have not been tested.
- An existing Warcraft III **1.26a / 1.26.0.6401** installation. Other versions are rejected before any changes.
- Internet access to download the selected modules from their authors' GitHub releases, and write access to the selected game folder.
- Intended for single-player use. The unlocker author warns of a possible conflict with iCCup's anti-cheat.
- If access is denied, use a game folder you can write to. The installer does not request administrator privileges automatically.
- The installer interface is currently in Russian. The relevant button names are translated in the steps above.

### Third-party components

This installer uses **[FPS Unlocker](https://github.com/UnryzeC/WC3_FPSUnlocker)**,
a third-party component by **UnryzeC (Unryze)**. It is a separate project developed by its own author.

The installer downloads `FPSUnlocker.mix` version **1.1.0.5** directly from
[the author's release](https://github.com/UnryzeC/WC3_FPSUnlocker/releases/tag/v1.1.0.5)
and verifies its SHA-256 before installation:

```text
f3b497d961a5d4e2a8a089773fde99fae2e020a8729f9a37d6f53a8216e9405c
```

**[W3TrueWidescreen](https://github.com/Hr0ffT/W3TrueWidescreen)** is a separate project by **Hr0ffT**, distributed under
[its own MIT license](https://github.com/Hr0ffT/W3TrueWidescreen/blob/v1.20/LICENSE).
When selected, the installer downloads [version 1.20](https://github.com/Hr0ffT/W3TrueWidescreen/releases/tag/v1.20)
directly from its author and verifies the ZIP archive's SHA-256:

```text
b60343aa49a18e25ffea8d04c34064bb230eb123ee992d0b5b7ee2932fdc2b62
```

Only `W3TrueWidescreen.mix`, the configured `W3TrueWidescreen.ini`, and the author's license
(`W3TrueWidescreen.LICENSE.txt`) are installed. The archive's optional movie renderer is not installed.

This repository contains no Warcraft III game files, saved games, game keys, or copies of the third-party binaries.
The MIT license in this repository covers this installer's code and documentation. The game and third-party components retain their respective rights and licenses.

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

Установщик FPS Unlocker и дополнительного W3TrueWidescreen для **Warcraft III 1.26a** (Reign of Chaos и The Frozen Throne).
Помогает убрать внутреннее ограничение около 64 FPS, исправить растянутые пропорции игрового мира
и настроить игру под монитор с высокой частотой обновления.

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

### Широкий экран и HUD

**Исправление растяжения и HUD на всю ширину включены по умолчанию.**

| Опция установщика | Результат |
| --- | --- |
| **Исправить растяжение игрового мира** | Устанавливает W3TrueWidescreen: исправляет пропорции мира и поле зрения на широком мониторе. |
| **HUD на всю ширину экрана** | Растягивает нижнюю панель по ширине экрана, сохраняя правильные пропорции игрового мира. |
| Галочка широкого HUD снята | Панель сохраняет исходные пропорции и становится более узкой, по центру экрана. |
| Галочка исправления растяжения снята | Widescreen-патч не устанавливается; FPS Unlocker всё равно будет установлен. |

Снятая галочка пропускает компонент при этом запуске, но не удаляет уже установленный патч. Для отмены установки используйте **Восстановить**.
Готовые настройки сохраняют исходное расстояние камеры и стандартный размер интерфейса.
Собственное снятие FPS-лимита в W3TrueWidescreen отключено: за FPS отвечает FPS Unlocker.
Дополнительные видеокодеки, HDR-перехватчики и новые горячие клавиши не включаются.
Для исправления широкого экрана нужен стандартный рендерер **Direct3D**; ярлыки с параметром `-opengl` не поддерживаются.

Чтобы включить встроенный счётчик кадров, в матче нажмите Enter, введите `/fps` и снова нажмите Enter.
FPS зависит от компьютера, карты и сцены. Анлокер может обходить штатный лимит `maxfps`,
поэтому счётчик способен показывать больше кадров, чем частота монитора.

### Как отменить изменения

Снова запустите **Install.cmd**, укажите ту же папку игры и нажмите **Восстановить**.
Установщик вернёт прежние видеонастройки и прежние версии заменённых файлов, если они уже были в игре.
Добавленные им новые файлы будут удалены, в том числе W3TrueWidescreen, если он устанавливался этой программой.
Если widescreen-патч ранее ставился вручную, его прежние файлы сохраняются перед заменой и возвращаются при откате.
Ручные изменения установленного widescreen-конфига также сохраняются в отдельную копию перед откатом.

Исходное состояние хранится в папке `.warcraft-fps-setup` внутри игры. Сохраните её до восстановления.
Повторная установка сохраняет первоначальную резервную копию.
Видеонастройки общие для копий Warcraft III в одной учётной записи Windows;
анлокер устанавливается только в выбранную папку.

### Требования и ограничения

- Windows 10/11 с Windows PowerShell 5.1; на других системах установщик не проверялся.
- Уже установленный Warcraft III **1.26a / 1.26.0.6401**. Другие версии отклоняются до изменений.
- Интернет для скачивания выбранных модулей из GitHub-релизов авторов и право записи в выбранную папку игры.
- Установщик предназначен для одиночной игры. Автор анлокера предупреждает о возможном конфликте с античитом iCCup.
- При ошибке доступа используйте доступную для записи папку игры. Установщик сам не запрашивает права администратора.
- Интерфейс установщика сейчас доступен на русском языке.

### Сторонние компоненты

Используется сторонний **[FPS Unlocker](https://github.com/UnryzeC/WC3_FPSUnlocker)**,
автор — **UnryzeC (Unryze)**. Это отдельный проект, не разработка Sw1ziy.

Установщик скачивает `FPSUnlocker.mix` версии **1.1.0.5** напрямую из
[релиза автора](https://github.com/UnryzeC/WC3_FPSUnlocker/releases/tag/v1.1.0.5)
и проверяет SHA-256 перед установкой:

```text
f3b497d961a5d4e2a8a089773fde99fae2e020a8729f9a37d6f53a8216e9405c
```

**[W3TrueWidescreen](https://github.com/Hr0ffT/W3TrueWidescreen)** — отдельный проект **Hr0ffT**,
распространяемый по [собственной лицензии MIT](https://github.com/Hr0ffT/W3TrueWidescreen/blob/v1.20/LICENSE).
При выборе этого компонента установщик скачивает [версию 1.20](https://github.com/Hr0ffT/W3TrueWidescreen/releases/tag/v1.20)
напрямую у автора и проверяет SHA-256 ZIP-архива:

```text
b60343aa49a18e25ffea8d04c34064bb230eb123ee992d0b5b7ee2932fdc2b62
```

Устанавливаются только `W3TrueWidescreen.mix`, настроенный `W3TrueWidescreen.ini` и лицензия автора
(`W3TrueWidescreen.LICENSE.txt`). Дополнительный видеорендерер из архива не устанавливается.

В этом репозитории нет файлов Warcraft III, сохранений, ключей игры или копий сторонних бинарных модулей.
Лицензия MIT в этом репозитории относится к коду и документации установщика. Права и лицензии игры и сторонних компонентов сохраняются за их авторами.

### Проверка исходников

В PowerShell из папки проекта:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Test-Installer.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File Setup.ps1 -CheckOnly
```

Тесты используют отдельный временный каталог и отдельную ветку реестра.
Реальные настройки и сохранения игры при тестировании не изменяются.

[К выбору языка](#warcraft-iii-fps-setup)
