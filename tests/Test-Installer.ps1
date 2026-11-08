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
$settings = @{reswidth=2560; resheight=1440; refreshrate=200}

# Only these two external operations are replaced. Files, hashes, version
# detection, state persistence, registry writes and restore run for real.
function Assert-GameClosed {
    if ($script:BlockGame) { throw 'Test: game is running.' }
}
function Receive-Unlocker([string]$Destination) {
    $script:Downloads++
    if ($script:FailDownload) { throw 'Test: download failed.' }
    Copy-Item -LiteralPath $script:FixtureModule -Destination $Destination -Force
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
