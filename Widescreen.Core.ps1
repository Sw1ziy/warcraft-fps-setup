# Copyright (c) 2026 Sw1ziy. MIT License.
$script:WidescreenUrl = 'https://github.com/Hr0ffT/W3TrueWidescreen/releases/download/v1.20/W3TrueWidescreen-1.20.zip'
$script:WidescreenSha256 = 'b60343aa49a18e25ffea8d04c34064bb230eb123ee992d0b5b7ee2932fdc2b62'
$script:WidescreenFiles = @('W3TrueWidescreen.mix', 'W3TrueWidescreen.ini', 'W3TrueWidescreen.LICENSE.txt')

function Get-BytesHash([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-WidescreenPreset([string]$Ini, [bool]$FullWidthHud) {
    # FPS stays with FPSUnlocker.mix. Install only widescreen correction;
    # optional movie codecs, HDR hooks and extra shortcuts are left disabled.
    $options = [ordered]@{
        WorldFullHeight = '1'; FovFix = '1'; CameraZoomOut = '1.0'
        StretchedConsole = $(if ($FullWidthHud) { '1' } else { '0' })
        UIScale = '100'; FpsLimit = '0'; ScoreScreen = '2'
        MovieNativeMode = '0'; MovieRenderer = '0'; MovieSuperRes = '0'
        MoviePlayer = '0'; AllowPathQuery = '0'; HideUIKey = ''
    }
    foreach ($entry in $options.GetEnumerator()) {
        $pattern = '(?m)^' + [regex]::Escape($entry.Key) + '=[^\r\n]*'
        if ([regex]::Matches($Ini, $pattern).Count -ne 1) {
            throw "Неожиданный формат настроек widescreen-патча: $($entry.Key). Установка отменена."
        }
        $Ini = [regex]::Replace($Ini, $pattern, ($entry.Key + '=' + $entry.Value))
    }
    return $Ini
}

function Receive-WidescreenArchive([string]$Destination) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $script:WidescreenUrl -OutFile $Destination -UseBasicParsing -TimeoutSec 90 -ErrorAction Stop
}

function Receive-WidescreenPackage([bool]$FullWidthHud = $true) {
    $download = [IO.Path]::GetTempFileName()
    $archive = $null
    try {
        Receive-WidescreenArchive $download
        if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -ne $script:WidescreenSha256) {
            throw 'Контрольная сумма widescreen-патча не совпала. Установка отменена.'
        }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($download)
        $package = @{}
        # Read only these exact entries; do not extract arbitrary archive paths.
        $entries = [ordered]@{
            'W3TrueWidescreen.mix' = 'W3TrueWidescreen.mix'
            'W3TrueWidescreen.ini' = 'W3TrueWidescreen.ini'
            'W3TrueWidescreen.LICENSE.txt' = 'LICENSE'
        }
        foreach ($item in $entries.GetEnumerator()) {
            $entry = $archive.GetEntry($item.Value)
            if ($null -eq $entry -or $entry.Length -lt 1 -or $entry.Length -gt 20MB) {
                throw "Не найден или повреждён файл widescreen-патча: $($item.Value)."
            }
            $stream = $entry.Open()
            $buffer = New-Object IO.MemoryStream
            try { $stream.CopyTo($buffer); $package[$item.Key] = $buffer.ToArray() }
            finally { $stream.Dispose(); $buffer.Dispose() }
        }
        $ini = [Text.Encoding]::ASCII.GetString($package['W3TrueWidescreen.ini'])
        $package['W3TrueWidescreen.ini'] = [Text.Encoding]::ASCII.GetBytes((Get-WidescreenPreset $ini $FullWidthHud))
        return $package
    } finally {
        if ($archive) { $archive.Dispose() }
        if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Force }
    }
}

function Get-WidescreenState([string]$GameFolder) {
    $data = Join-Path $GameFolder '.warcraft-fps-setup'
    $path = Join-Path $data 'widescreen-state.json'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $state = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json
    if ($state.Format -ne 1 -or $state.GameFolder -ne $GameFolder -or @($state.Files).Count -ne $script:WidescreenFiles.Count) {
        throw 'Некорректная резервная копия widescreen-патча.'
    }
    $names = @($state.Files | ForEach-Object { $_.Name } | Select-Object -Unique)
    if ($names.Count -ne $script:WidescreenFiles.Count) { throw 'Повторяющиеся файлы в резервной копии.' }
    foreach ($file in $state.Files) {
        if ($script:WidescreenFiles -notcontains $file.Name) { throw 'Неизвестный файл в резервной копии widescreen-патча.' }
        if ($file.Existed -and -not (Test-Path -LiteralPath (Join-Path $data ('widescreen-before-' + $file.Name)) -PathType Leaf)) {
            throw "Не найден прежний файл widescreen-патча: $($file.Name)."
        }
    }
    return $state
}

function Install-WidescreenFiles([string]$GameFolder, [hashtable]$Package) {
    $data = Join-Path $GameFolder '.warcraft-fps-setup'
    $state = Get-WidescreenState $GameFolder
    if (-not $state) {
        $files = @()
        foreach ($name in $script:WidescreenFiles) {
            $target = Join-Path $GameFolder $name
            $existed = Test-Path -LiteralPath $target -PathType Leaf
            if ($existed) {
                Copy-Item -LiteralPath $target -Destination (Join-Path $data ('widescreen-before-' + $name)) -Force -ErrorAction Stop
            }
            $files += [pscustomobject]@{Name=$name; Existed=$existed; InstalledSha256=''}
        }
        $state = [pscustomobject]@{Format=1; GameFolder=$GameFolder; Files=$files}
    }
    foreach ($file in $state.Files) { $file.InstalledSha256 = Get-BytesHash $Package[$file.Name] }
    Save-SetupState -State $state -Directory $data -FileName 'widescreen-state.json'
    foreach ($name in $script:WidescreenFiles) { [IO.File]::WriteAllBytes((Join-Path $GameFolder $name), $Package[$name]) }
}

function Assert-WidescreenRestorable([string]$GameFolder, $State) {
    $module = $State.Files | Where-Object { $_.Name -eq 'W3TrueWidescreen.mix' }
    $target = Join-Path $GameFolder $module.Name
    if (Test-Path -LiteralPath $target) {
        $currentHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        if ($currentHash -ne $module.InstalledSha256) {
            $data = Join-Path $GameFolder '.warcraft-fps-setup'
            $backup = Join-Path $data ('widescreen-before-' + $module.Name)
            # Allow retry after a partially completed restore, too.
            if (-not $module.Existed -or $currentHash -ne (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash) {
                throw 'Widescreen-модуль был заменён после установки. Восстановление остановлено, чтобы сохранить этот файл.'
            }
        }
    }
}

function Restore-WidescreenFiles([string]$GameFolder, $State) {
    $data = Join-Path $GameFolder '.warcraft-fps-setup'
    $ini = Join-Path $GameFolder 'W3TrueWidescreen.ini'
    if (Test-Path -LiteralPath $ini) {
        # Preserve manual tweaks even when restoring an earlier configuration.
        Copy-Item -LiteralPath $ini -Destination (Join-Path $data ('widescreen-config-removed-' + [Guid]::NewGuid().ToString('N') + '.ini')) -ErrorAction Stop
    }
    foreach ($file in $State.Files) {
        $target = Join-Path $GameFolder $file.Name
        if ($file.Existed) {
            Copy-Item -LiteralPath (Join-Path $data ('widescreen-before-' + $file.Name)) -Destination $target -Force -ErrorAction Stop
        } elseif (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Force -ErrorAction Stop
        }
    }
    Move-Item -LiteralPath (Join-Path $data 'widescreen-state.json') -Destination (Join-Path $data ('widescreen-restored-' + [Guid]::NewGuid().ToString('N') + '.json')) -ErrorAction Stop
}
