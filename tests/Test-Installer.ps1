$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Installer.Core.ps1')

function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Expect-Failure([scriptblock]$Action, [string]$Message) {
    $failed = $false
    try { & $Action } catch { $failed = $true }
    Assert $failed $Message
}

$testId = [Guid]::NewGuid().ToString('N')
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('warcraft-fps-test-' + $testId)
$registryRoot = 'HKCU:\Software\WarcraftFpsSetupTests\' + $testId
$script:VideoKey = $registryRoot + '\Video'
$expectedRoot = [IO.Path]::GetFullPath($testRoot)
$script:Downloads = 0
$script:FailDownload = $false
$script:BlockGame = $false
$script:FailWideDownload = $false
$settings = @{reswidth=2560; resheight=1440; refreshrate=200}

# Only process detection and network downloads are replaced. Files, hashes, version
# detection, state persistence, registry writes and restore run for real.
function Assert-GameClosed {
    if ($script:BlockGame) { throw 'Test: game is running.' }
}
function Receive-Unlocker([string]$Destination) {
    $script:Downloads++
    if ($script:FailDownload) { throw 'Test: download failed.' }
    Copy-Item -LiteralPath $script:FixtureModule -Destination $Destination -Force
}
function Receive-WidescreenArchive([string]$Destination) {
    if ($script:FailWideDownload) { throw 'Test: widescreen download failed.' }
    Copy-Item -LiteralPath $script:FixtureWideArchive -Destination $Destination -Force
}
function New-TestGame([string]$Name) {
    $folder = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path $folder | Out-Null
    Copy-Item -LiteralPath (Join-Path $testRoot 'version-fixture.dll') -Destination (Join-Path $folder 'game.dll')
    Set-Content -LiteralPath (Join-Path $folder 'war3.exe') -Value 'Not an executable; test fixture only.'
    return $folder
}
function Reset-TestVideo {
    if (Test-Path -LiteralPath $script:VideoKey) {
        foreach ($name in $script:VideoNames) {
            Remove-ItemProperty -LiteralPath $script:VideoKey -Name $name -ErrorAction SilentlyContinue
        }
    } else {
        New-Item -Path $script:VideoKey -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $script:VideoKey -Name reswidth -Value 1920 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -LiteralPath $script:VideoKey -Name gamma -Value 42 -PropertyType DWord -Force | Out-Null
}

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    Add-Type -TypeDefinition @'
using System.Reflection;
[assembly: AssemblyFileVersion("1.26.0.6401")]
public class WarcraftVersionFixture {}
'@ -OutputAssembly (Join-Path $testRoot 'version-fixture.dll') -OutputType Library
    $script:FixtureModule = Join-Path $testRoot 'download-fixture.bin'
    Set-Content -LiteralPath $script:FixtureModule -Value 'Fixture module, never executed.'
    $script:UnlockerSha256 = (Get-FileHash -LiteralPath $script:FixtureModule -Algorithm SHA256).Hash
    $wideFixture = Join-Path $testRoot 'wide-fixture'
    New-Item -ItemType Directory -Path $wideFixture | Out-Null
    Set-Content -LiteralPath (Join-Path $wideFixture 'W3TrueWidescreen.mix') -Value 'Widescreen fixture module; never executed.'
    $wideIni = @'
[W3TrueWidescreen]
WorldFullHeight=1
FovFix=1
CameraZoomOut=1.0
StretchedConsole=0
UIScale=100
FpsLimit=0
ScoreScreen=3
MovieNativeMode=1
MovieRenderer=1
MovieSuperRes=1
MoviePlayer=0
AllowPathQuery=1
HideUIKey=Ctrl+H
'@
    Set-Content -LiteralPath (Join-Path $wideFixture 'W3TrueWidescreen.ini') -Value $wideIni -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $wideFixture 'LICENSE') -Value 'Third-party fixture license.'
    Set-Content -LiteralPath (Join-Path $wideFixture 'ignored-codec.dll') -Value 'Do not install this archive entry.'
    $script:FixtureWideArchive = Join-Path $testRoot 'wide-fixture.zip'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($wideFixture, $script:FixtureWideArchive)
    $script:WidescreenSha256 = (Get-FileHash -LiteralPath $script:FixtureWideArchive -Algorithm SHA256).Hash
    Reset-TestVideo

    $game = New-TestGame 'fresh'
    Install-FpsFix -GamePath $game -DisplaySettings $settings
    Assert ((Get-ItemPropertyValue -LiteralPath $script:VideoKey -Name refreshrate) -eq 200) 'Refresh rate applied'
    Assert ((Get-ItemPropertyValue -LiteralPath $script:VideoKey -Name gamma) -eq 42) 'Unrelated settings preserved'
    Install-FpsFix -GamePath $game -DisplaySettings $settings
    Restore-FpsFix $game
    Assert (-not (Test-Path -LiteralPath (Join-Path $game 'FPSUnlocker.mix'))) 'Fresh module removed on restore'
    Assert ((Get-ItemPropertyValue -LiteralPath $script:VideoKey -Name reswidth) -eq 1920) 'Original resolution survives reinstall'
    Assert (-not ((Get-Item -LiteralPath $script:VideoKey).GetValueNames() -contains 'maxfps')) 'Previously absent value removed'
    Assert ((Get-ItemPropertyValue -LiteralPath $script:VideoKey -Name gamma) -eq 42) 'Unrelated setting survives restore'
    Write-Output 'PASS: install, reinstall, restore, unrelated settings'

    $game = New-TestGame 'existing-module'
    $module = Join-Path $game 'FPSUnlocker.mix'
    Set-Content -LiteralPath $module -Value 'Original module.'
    $originalHash = (Get-FileHash -LiteralPath $module -Algorithm SHA256).Hash
    Install-FpsFix -GamePath $game
    Install-FpsFix -GamePath $game
    Set-Content -LiteralPath $module -Value 'Changed by another tool.'
    Expect-Failure { Restore-FpsFix $game } 'Replacement by another tool must be preserved'
    Assert ((Get-Content -LiteralPath $module -Raw) -match 'Changed by another tool') 'Replacement file preserved'
    Copy-Item -LiteralPath $script:FixtureModule -Destination $module -Force
    Restore-FpsFix $game
    Assert ((Get-FileHash -LiteralPath $module -Algorithm SHA256).Hash -eq $originalHash) 'Pre-existing module restored'
    Write-Output 'PASS: pre-existing module and replacement protection'

    $game = New-TestGame 'bad-download'
    $goodHash = $script:UnlockerSha256
    $script:UnlockerSha256 = '0' * 64
    Expect-Failure { Install-FpsFix -GamePath $game -DisplaySettings $settings } 'Incorrect hash rejected'
    $script:UnlockerSha256 = $goodHash
    $script:FailDownload = $true
    Expect-Failure { Install-FpsFix -GamePath $game } 'Network failure reported'
    $script:FailDownload = $false
    Assert (-not (Test-Path -LiteralPath (Join-Path $game '.warcraft-fps-setup'))) 'Failed downloads do not create backup or alter module'
    Assert ((Get-ItemPropertyValue -LiteralPath $script:VideoKey -Name reswidth) -eq 1920) 'Failed download leaves settings unchanged'
    Write-Output 'PASS: hash mismatch and network failure leave game unchanged'

    $game = New-TestGame 'unsupported'
    Set-Content -LiteralPath (Join-Path $game 'game.dll') -Value 'Wrong version.'
    $beforeDownloads = $script:Downloads
    Expect-Failure { Install-FpsFix -GamePath $game } 'Unsupported game rejected'
    $game = New-TestGame 'running'
    $script:BlockGame = $true
    Expect-Failure { Install-FpsFix -GamePath $game } 'Running game rejected'
    $script:BlockGame = $false
    Assert ($beforeDownloads -eq $script:Downloads) 'Validation happens before downloading'
    Write-Output 'PASS: version and running-game checks happen before changes'

    $game = New-TestGame 'optional-settings'
    $beforeVideo = @(Get-VideoSnapshot) | ConvertTo-Json -Depth 4
    Install-FpsFix -GamePath $game
    $afterVideo = @(Get-VideoSnapshot) | ConvertTo-Json -Depth 4
    Assert ($beforeVideo -eq $afterVideo) 'Module-only installation preserves all video settings'
    New-ItemProperty -LiteralPath $script:VideoKey -Name reswidth -Value 1680 -PropertyType DWord -Force | Out-Null
    Install-FpsFix -GamePath $game -DisplaySettings $settings
    Restore-FpsFix $game
    Assert ((Get-ItemPropertyValue -LiteralPath $script:VideoKey -Name reswidth) -eq 1680) 'Late opt-in backs up settings at time of first actual change'
    Write-Output 'PASS: optional display settings and late opt-in'

    Reset-TestVideo
    $game = New-TestGame 'combined-fresh'
    Install-FpsFix -GamePath $game -DisplaySettings $settings -Widescreen
    foreach ($name in $script:WidescreenFiles) {
        Assert (Test-Path -LiteralPath (Join-Path $game $name)) "Selected component file installed: $name"
    }
    $iniPath = Join-Path $game 'W3TrueWidescreen.ini'
    $iniText = Get-Content -LiteralPath $iniPath -Raw
    Assert ($iniText -match '(?m)^StretchedConsole=1\r?$') 'Full-width HUD is the default'
    Assert ($iniText -match '(?m)^FpsLimit=0\r?$') 'Second FPS patch disabled'
    Assert ($iniText -match '(?m)^MovieRenderer=0\r?$') 'Optional movie renderer disabled'
    Assert (-not (Test-Path -LiteralPath (Join-Path $game 'ignored-codec.dll'))) 'Only selected archive files installed'
    Install-FpsFix -GamePath $game -Widescreen -FullWidthHud $false
    Assert ((Get-Content -LiteralPath $iniPath -Raw) -match '(?m)^StretchedConsole=0\r?$') 'Narrow HUD can be selected on reinstall'
    Add-Content -LiteralPath $iniPath -Value '; Manual change to preserve during restore'
    Restore-FpsFix $game
    foreach ($name in $script:WidescreenFiles) {
        Assert (-not (Test-Path -LiteralPath (Join-Path $game $name))) "New component file removed on restore: $name"
    }
    Assert (-not (Test-Path -LiteralPath (Join-Path $game 'FPSUnlocker.mix'))) 'Combined restore removes new FPS module'
    Assert ((Get-ItemPropertyValue -LiteralPath $script:VideoKey -Name reswidth) -eq 1920) 'Combined restore returns original video settings'
    $removedConfigs = @(Get-ChildItem -LiteralPath (Join-Path $game '.warcraft-fps-setup') -Filter 'widescreen-config-removed-*.ini')
    Assert ($removedConfigs.Count -eq 1) 'Edited widescreen config archived during restore'
    Assert ((Get-Content -LiteralPath $removedConfigs[0].FullName -Raw) -match 'Manual change to preserve') 'Manual config edits preserved in archive'
    Write-Output 'PASS: combined install, HUD selection, reinstall and restore'

    $game = New-TestGame 'existing-widescreen'
    $originalFiles = @{}
    foreach ($name in $script:WidescreenFiles) {
        $target = Join-Path $game $name
        Set-Content -LiteralPath $target -Value ("Original third-party file: $name")
        $originalFiles[$name] = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    }
    # This state has the exact schema used before widescreen support was added.
    Install-FpsFix -GamePath $game
    foreach ($name in $script:WidescreenFiles) {
        Assert ((Get-FileHash -LiteralPath (Join-Path $game $name) -Algorithm SHA256).Hash -eq $originalFiles[$name]) 'FPS-only install preserves manually installed widescreen files'
    }
    Install-FpsFix -GamePath $game -DisplaySettings $settings -Widescreen
    $wideModule = Join-Path $game 'W3TrueWidescreen.mix'
    Set-Content -LiteralPath $wideModule -Value 'A replacement from another tool.'
    Expect-Failure { Restore-FpsFix $game } 'External widescreen replacement blocks combined restore'
    Assert ((Get-ItemPropertyValue -LiteralPath $script:VideoKey -Name reswidth) -eq 2560) 'Conflict detected before restoring video settings'
    Assert (Test-Path -LiteralPath (Join-Path $game 'FPSUnlocker.mix')) 'Conflict detected before removing FPS module'
    Copy-Item -LiteralPath (Join-Path $wideFixture 'W3TrueWidescreen.mix') -Destination $wideModule -Force
    Install-FpsFix -GamePath $game -Widescreen
    Restore-FpsFix $game
    foreach ($name in $script:WidescreenFiles) {
        Assert ((Get-FileHash -LiteralPath (Join-Path $game $name) -Algorithm SHA256).Hash -eq $originalFiles[$name]) "Pre-existing third-party file restored exactly: $name"
    }
    Write-Output 'PASS: old installer state, existing widescreen files and replacement protection'

    Reset-TestVideo
    $game = New-TestGame 'bad-wide-download'
    $goodWideHash = $script:WidescreenSha256
    $script:WidescreenSha256 = '0' * 64
    Expect-Failure { Install-FpsFix -GamePath $game -DisplaySettings $settings -Widescreen } 'Bad widescreen checksum rejected'
    $script:WidescreenSha256 = $goodWideHash
    $script:FailWideDownload = $true
    Expect-Failure { Install-FpsFix -GamePath $game -DisplaySettings $settings -Widescreen } 'Widescreen network error reported'
    $script:FailWideDownload = $false
    Assert (-not (Test-Path -LiteralPath (Join-Path $game '.warcraft-fps-setup'))) 'Failed optional downloads leave no game state'
    Assert (-not (Test-Path -LiteralPath (Join-Path $game 'FPSUnlocker.mix'))) 'Failed optional download does not install FPS module either'
    Assert ((Get-ItemPropertyValue -LiteralPath $script:VideoKey -Name reswidth) -eq 1920) 'Failed optional download preserves registry'
    Expect-Failure { Get-WidescreenPreset ($wideIni.Replace('FpsLimit=0', '')) $true } 'Incomplete upstream config rejected'
    Write-Output 'PASS: optional download failures are detected before any game changes'
    Write-Output 'All installer checks passed.'
} finally {
    if (([IO.Path]::GetFullPath($testRoot) -ne $expectedRoot) -or -not $testRoot.EndsWith($testId)) {
        throw 'Unexpected test cleanup directory.'
    }
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).Path
        if ($resolvedTestRoot -ne $expectedRoot) { throw 'Unexpected resolved cleanup directory.' }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
    if ($registryRoot -ne ('HKCU:\Software\WarcraftFpsSetupTests\' + $testId)) {
        throw 'Unexpected test registry cleanup path.'
    }
    if (Test-Path -LiteralPath $registryRoot) { Remove-Item -LiteralPath $registryRoot -Recurse -Force }
}
