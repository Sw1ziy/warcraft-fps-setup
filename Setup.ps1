# Copyright (c) 2026 Sw1ziy. MIT License.
param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Installer.Core.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WarcraftDisplay {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DevMode {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string DeviceName;
        public short SpecVersion, DriverVersion, Size, DriverExtra;
        public int Fields, PositionX, PositionY, Orientation, FixedOutput;
        public short Color, Duplex, YResolution, TTOption, Collate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string FormName;
        public short LogPixels;
        public int BitsPerPel, Width, Height, DisplayFlags, Frequency;
        public int ICMMethod, ICMIntent, MediaType, DitherType, Reserved1, Reserved2;
        public int PanningWidth, PanningHeight;
    }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern bool EnumDisplaySettings(string device, int mode, ref DevMode settings);
    public static int[] Current(string device) {
        var mode = new DevMode();
        mode.Size = (short)Marshal.SizeOf(typeof(DevMode));
        if (!EnumDisplaySettings(device, -1, ref mode)) return null;
        return new int[] { mode.Width, mode.Height, mode.Frequency };
    }
}
'@
[Windows.Forms.Application]::EnableVisualStyles()
$screen = [Windows.Forms.Screen]::PrimaryScreen
$displayMode = [WarcraftDisplay]::Current($screen.DeviceName)
$form = New-Object Windows.Forms.Form
$form.Text = 'Warcraft III FPS Setup'
$form.ClientSize = New-Object Drawing.Size(610, 340)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Font = New-Object Drawing.Font('Segoe UI', 10)

function Add-Label([string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $Text
    $label.SetBounds($X, $Y, $Width, $Height)
    $form.Controls.Add($label)
    return $label
}
$title = Add-Label 'Плавнее играть в Warcraft III' 22 18 560 32
$title.Font = New-Object Drawing.Font('Segoe UI', 15, [Drawing.FontStyle]::Bold)
$null = Add-Label 'Установка FPS Unlocker для классической версии 1.26a.' 22 57 565 26
$null = Add-Label 'Папка игры:' 22 96 550 24
$pathBox = New-Object Windows.Forms.TextBox
$pathBox.SetBounds(22, 124, 445, 29)
$form.Controls.Add($pathBox)
$browse = New-Object Windows.Forms.Button
$browse.Text = 'Обзор...'
$browse.SetBounds(477, 122, 108, 32)
$form.Controls.Add($browse)

$documents = [Environment]::GetFolderPath('MyDocuments')
$candidates = @(
    (Join-Path $documents 'My Games\Warcraft III'),
    (Join-Path $documents 'Warcraft III'),
    (Join-Path ${env:ProgramFiles(x86)} 'Warcraft III'),
    (Join-Path $env:ProgramFiles 'Warcraft III')
)
foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath (Join-Path $candidate 'war3.exe')) { $pathBox.Text = $candidate; break }
}
$displayBox = New-Object Windows.Forms.CheckBox
$displayBox.SetBounds(22, 168, 565, 44)
$displayBox.Checked = $null -ne $displayMode -and $displayMode[2] -gt 1
$displayBox.Enabled = $displayBox.Checked
if ($displayBox.Enabled) {
    $displayBox.Text = "Настроить игру под основной экран: $($displayMode[0]) x $($displayMode[1]), $($displayMode[2]) Гц"
} else {
    $displayBox.Text = 'Режим экрана не определён. Будет установлен только анлокер.'
}
$form.Controls.Add($displayBox)
$install = New-Object Windows.Forms.Button
$install.Text = 'Установить'
$install.SetBounds(22, 227, 155, 38)
$form.Controls.Add($install)
$restore = New-Object Windows.Forms.Button
$restore.Text = 'Восстановить'
$restore.SetBounds(189, 227, 155, 38)
$form.Controls.Add($restore)
$status = Add-Label 'Нужен интернет. Перед установкой закройте игру.' 22 276 565 30
$null = Add-Label 'Разработчик установщика: Sw1ziy' 22 311 565 24

$browse.Add_Click({
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Выберите папку Warcraft III с файлом war3.exe'
    $dialog.ShowNewFolderButton = $false
    if (Test-Path -LiteralPath $pathBox.Text -PathType Container) { $dialog.SelectedPath = $pathBox.Text }
    if ($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK) { $pathBox.Text = $dialog.SelectedPath }
    $dialog.Dispose()
})
function Invoke-SetupAction([bool]$Restore) {
    $install.Enabled = $false
    $restore.Enabled = $false
    $browse.Enabled = $false
    $pathBox.Enabled = $false
    $displayBox.Enabled = $false
    $form.ControlBox = $false
    $form.UseWaitCursor = $true
    $status.Text = $(if ($Restore) { 'Восстановление...' } else { 'Скачивание и установка анлокера...' })
    $form.Refresh()
    try {
        if ($Restore) {
            Restore-FpsFix $pathBox.Text.Trim().Trim('"')
            $message = 'Прежние настройки и файл анлокера восстановлены.'
        } else {
            $settings = $null
            if ($displayBox.Checked) {
                $settings = @{reswidth=$displayMode[0]; resheight=$displayMode[1]; refreshrate=$displayMode[2]}
            }
            Install-FpsFix -GamePath $pathBox.Text.Trim().Trim('"') -DisplaySettings $settings
            $message = "Готово! Запустите игру обычным ярлыком.`nДля счётчика кадров введите /fps в игровом чате."
        }
        $status.Text = 'Готово.'
        [Windows.Forms.MessageBox]::Show($form, $message, $form.Text, 'OK', 'Information') | Out-Null
    } catch {
        $status.Text = 'Не удалось завершить операцию.'
        [Windows.Forms.MessageBox]::Show($form, $_.Exception.Message, $form.Text, 'OK', 'Error') | Out-Null
    } finally {
        $install.Enabled = $true
        $restore.Enabled = $true
        $browse.Enabled = $true
        $pathBox.Enabled = $true
        $displayBox.Enabled = $null -ne $displayMode -and $displayMode[2] -gt 1
        $form.ControlBox = $true
        $form.UseWaitCursor = $false
    }
}
$install.Add_Click({ Invoke-SetupAction $false })
$restore.Add_Click({ Invoke-SetupAction $true })
$form.AcceptButton = $install
if ($CheckOnly) {
    Write-Output "Developer: Sw1ziy; Display: $($displayMode -join ' x '); Controls: $($form.Controls.Count); Status: OK"
    $form.Dispose()
    return
}
[Windows.Forms.Application]::Run($form)
$form.Dispose()
