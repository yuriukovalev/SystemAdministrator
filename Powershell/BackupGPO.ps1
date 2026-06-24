<#
BackupGPO.ps1
---------------------------------------------
Резервное копирование всех объектов групповой политики (GPO) домена
в папку с датой + автоматическая ротация старых бэкапов.
Рассчитан на запуск по расписанию (Task Scheduler).

Требуется модуль GroupPolicy (входит в RSAT / роль AD DS).
#>

Import-Module GroupPolicy

$backupRoot   = "C:\Backup\GPO"
$keepDays     = 30                       # сколько дней хранить бэкапы
$stamp        = Get-Date -Format "yyyy-MM-dd_HHmm"
$backupPath   = Join-Path $backupRoot $stamp

# Создаём папку под текущий бэкап
New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

# Бэкапим все GPO
$result = Backup-GPO -All -Path $backupPath
Write-Output "Сохранено GPO: $($result.Count) -> $backupPath"

# Ротация: удаляем папки бэкапов старше $keepDays дней
$cutoff = (Get-Date).AddDays(-$keepDays)
Get-ChildItem -Path $backupRoot -Directory |
    Where-Object { $_.CreationTime -lt $cutoff } |
    ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force
        Write-Output "Удалён старый бэкап: $($_.Name)"
    }

Write-Output "Готово. Бэкап GPO завершён."
