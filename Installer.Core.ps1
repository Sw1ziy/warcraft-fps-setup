# Copyright (c) 2026 Sw1ziy. MIT License.
$script:UnlockerUrl = 'https://github.com/UnryzeC/WC3_FPSUnlocker/releases/download/v1.1.0.5/FPSUnlocker.mix'
$script:UnlockerSha256 = 'f3b497d961a5d4e2a8a089773fde99fae2e020a8729f9a37d6f53a8216e9405c'
$script:VideoKey = 'HKCU:\Software\Blizzard Entertainment\Warcraft III\Video'
$script:VideoNames = @('reswidth', 'resheight', 'refreshrate', 'maxfps', 'lockfb')
. (Join-Path $PSScriptRoot 'Widescreen.Core.ps1')

function Get-GameFolder([string]$Path) {
    $folder = (Get-Item -LiteralPath $Path -ErrorAction Stop).FullName
    if (-not (Test-Path -LiteralPath (Join-Path $folder 'war3.exe') -PathType Leaf)) {
        throw 'Выберите папку игры, в которой находится war3.exe.'
    }
    $dll = Get-Item -LiteralPath (Join-Path $folder 'game.dll') -ErrorAction Stop
    $v = $dll.VersionInfo
    if ("$($v.FileMajorPart).$($v.FileMinorPart).$($v.FileBuildPart).$($v.FilePrivatePart)" -ne '1.26.0.6401') {
        throw 'Этот установщик поддерживает Warcraft III 1.26a (1.26.0.6401). Другие версии пока не поддерживаются.'
    }
    return $folder
}

function Assert-GameClosed {
    if (Get-Process -Name 'war3', 'Warcraft III', 'Frozen Throne' -ErrorAction SilentlyContinue) {
        throw 'Сначала закройте Warcraft III, затем повторите установку или восстановление.'
    }
}

function Get-VideoSnapshot {
    $key = Get-Item -LiteralPath $script:VideoKey -ErrorAction SilentlyContinue
    foreach ($name in $script:VideoNames) {
        $exists = $null -ne $key -and $key.GetValueNames() -contains $name
        [pscustomobject]@{
            Name = $name
            Exists = $exists
            Value = $(if ($exists) { $key.GetValue($name) } else { $null })
            Kind = $(if ($exists) { $key.GetValueKind($name).ToString() } else { 'DWord' })
        }
    }
}

function Save-SetupState($State, [string]$Directory, [string]$FileName = 'state.json') {
    $statePath = Join-Path $Directory $FileName
    $tempState = $statePath + '.tmp'
    $State | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $tempState -Encoding UTF8
    if (Test-Path -LiteralPath $statePath) {
        $previous = [IO.Path]::GetFileNameWithoutExtension($FileName) + '.previous.json'
        [IO.File]::Replace($tempState, $statePath, (Join-Path $Directory $previous))
    } else {
        [IO.File]::Move($tempState, $statePath)
    }
}

function Read-SetupState([string]$Directory, [string]$GameFolder) {
    $state = Get-Content -LiteralPath (Join-Path $Directory 'state.json') -Raw -ErrorAction Stop | ConvertFrom-Json
    if ($state.Format -ne 1 -or $state.GameFolder -ne $GameFolder) {
        throw 'Резервная копия относится к другой папке или версии установщика.'
    }
    if ($state.PreviousModule -and -not (Test-Path -LiteralPath (Join-Path $Directory 'FPSUnlocker.previous'))) {
        throw 'Не найден сохранённый прежний анлокер. Восстановите папку резервной копии.'
    }
    foreach ($item in $state.Video) {
        if ($script:VideoNames -notcontains $item.Name) { throw 'Некорректная резервная копия настроек.' }
    }
    return $state
}

function Receive-Unlocker([string]$Destination) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $script:UnlockerUrl -OutFile $Destination -UseBasicParsing -TimeoutSec 90 -ErrorAction Stop
}

function Install-FpsFix {
    param(
        [Parameter(Mandatory = $true)][string]$GamePath,
        [hashtable]$DisplaySettings,
        [switch]$Widescreen,
        [bool]$FullWidthHud = $true
    )
    $folder = Get-GameFolder $GamePath
    Assert-GameClosed
    if ($DisplaySettings) {
        foreach ($name in @('reswidth', 'resheight', 'refreshrate')) {
            if (-not $DisplaySettings.ContainsKey($name) -or [int]$DisplaySettings[$name] -lt 1) {
                throw 'Не удалось определить режим монитора. Отключите настройку разрешения и повторите установку.'
            }
        }
    }
    $download = [IO.Path]::GetTempFileName()
    try {
        Receive-Unlocker $download
        if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -ne $script:UnlockerSha256) {
            throw 'Контрольная сумма анлокера не совпала. Установка отменена; повторите позже.'
        }
        # Download and validate every selected component before changing the game.
        $widePackage = $null
        if ($Widescreen) { $widePackage = Receive-WidescreenPackage -FullWidthHud $FullWidthHud }
        Assert-GameClosed
        $module = Join-Path $folder 'FPSUnlocker.mix'
        $data = Join-Path $folder '.warcraft-fps-setup'
        if (Test-Path -LiteralPath (Join-Path $data 'state.json')) {
            $state = Read-SetupState $data $folder
        } else {
            New-Item -ItemType Directory -Path $data -Force -ErrorAction Stop | Out-Null
            $previousModule = Test-Path -LiteralPath $module
            if ($previousModule) {
                Copy-Item -LiteralPath $module -Destination (Join-Path $data 'FPSUnlocker.previous') -ErrorAction Stop
            }
            $state = [pscustomobject]@{
                Format = 1
                GameFolder = $folder
                PreviousModule = $previousModule
                ManagedVideo = $false
                Video = @()
                InstalledSha256 = $script:UnlockerSha256
            }
        }
        if ($DisplaySettings -and -not $state.ManagedVideo) {
            $state.Video = @(Get-VideoSnapshot)
            $state.ManagedVideo = $true
        }
        $state.InstalledSha256 = $script:UnlockerSha256
        # Persist the original state before changing the module or registry.
        Save-SetupState $state $data
        try {
            Copy-Item -LiteralPath $download -Destination $module -Force -ErrorAction Stop
            if ($DisplaySettings) {
                if (-not (Test-Path -LiteralPath $script:VideoKey)) {
                    New-Item -Path $script:VideoKey -Force -ErrorAction Stop | Out-Null
                }
                $values = @{
                    reswidth = [int]$DisplaySettings.reswidth
                    resheight = [int]$DisplaySettings.resheight
                    refreshrate = [int]$DisplaySettings.refreshrate
                    maxfps = [int]$DisplaySettings.refreshrate
                    lockfb = 0
                }
                foreach ($entry in $values.GetEnumerator()) {
                    New-ItemProperty -LiteralPath $script:VideoKey -Name $entry.Key -Value $entry.Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null
                }
            }
            if ($widePackage) { Install-WidescreenFiles -GameFolder $folder -Package $widePackage }
        } catch {
            throw "Установка прервана. Резервная копия сохранена: используйте кнопку восстановления. $($_.Exception.Message)"
        }
    } finally {
        if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Force }
    }
}

function Restore-FpsFix([string]$GamePath) {
    $folder = Get-GameFolder $GamePath
    Assert-GameClosed
    $data = Join-Path $folder '.warcraft-fps-setup'
    $state = Read-SetupState $data $folder
    $module = Join-Path $folder 'FPSUnlocker.mix'
    if ((Test-Path -LiteralPath $module) -and (Get-FileHash -LiteralPath $module -Algorithm SHA256).Hash -ne $state.InstalledSha256) {
        throw 'Анлокер был заменён после установки. Автоматическое восстановление остановлено, чтобы сохранить этот файл.'
    }
    # Preflight both components before restoring either one.
    $wideState = Get-WidescreenState $folder
    if ($wideState) {
        Assert-WidescreenRestorable -GameFolder $folder -State $wideState
        Restore-WidescreenFiles -GameFolder $folder -State $wideState
    }
    if ($state.ManagedVideo) {
        if (-not (Test-Path -LiteralPath $script:VideoKey)) {
            New-Item -Path $script:VideoKey -Force -ErrorAction Stop | Out-Null
        }
        foreach ($item in $state.Video) {
            if ($item.Exists) {
                New-ItemProperty -LiteralPath $script:VideoKey -Name $item.Name -Value $item.Value -PropertyType $item.Kind -Force -ErrorAction Stop | Out-Null
            } else {
                Remove-ItemProperty -LiteralPath $script:VideoKey -Name $item.Name -ErrorAction SilentlyContinue
            }
        }
    }
    if ($state.PreviousModule) {
        Copy-Item -LiteralPath (Join-Path $data 'FPSUnlocker.previous') -Destination $module -Force -ErrorAction Stop
    } elseif (Test-Path -LiteralPath $module) {
        Remove-Item -LiteralPath $module -Force -ErrorAction Stop
    }
    # Keep the old state for inspection, but start a fresh backup next time.
    $archive = 'state-restored-' + [Guid]::NewGuid().ToString('N') + '.json'
    Move-Item -LiteralPath (Join-Path $data 'state.json') -Destination (Join-Path $data $archive) -ErrorAction Stop
}
