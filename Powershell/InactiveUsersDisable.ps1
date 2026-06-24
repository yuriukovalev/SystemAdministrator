<#
InactiveUsersDisable.ps1
---------------------------------------------
Находит включённые учётные записи, не входившие в домен дольше
заданного срока, и (опционально) отключает их с пометкой в Description.

По умолчанию работает в режиме предпросмотра (-WhatIf-подобно):
только формирует отчёт. Чтобы реально отключить — запустить с -Apply.
#>

[CmdletBinding()]
param(
    [int]$DaysInactive = 90,
    [switch]$Apply          # без этого ключа — только отчёт, без изменений
)

Import-Module ActiveDirectory

$cutoff     = (Get-Date).AddDays(-$DaysInactive)
$outputFile = "C:\Reports\InactiveUsers.csv"
$stamp      = Get-Date -Format "yyyy-MM-dd"

$users = Get-ADUser -Filter "Enabled -eq 'True'" `
    -Properties LastLogonDate, DistinguishedName |
    Where-Object { $_.LastLogonDate -and $_.LastLogonDate -lt $cutoff }

$report = foreach ($u in $users) {
    if ($Apply) {
        Disable-ADAccount -Identity $u
        Set-ADUser -Identity $u -Description "Отключён автоматически $stamp (неактивность > $DaysInactive дн.)"
    }
    [pscustomobject]@{
        SamAccountName = $u.SamAccountName
        Name           = $u.Name
        LastLogonDate  = $u.LastLogonDate
        Action         = if ($Apply) { "DISABLED" } else { "REPORT-ONLY" }
        DN             = $u.DistinguishedName
    }
}

$report | Sort-Object LastLogonDate |
    Export-Csv -Path $outputFile -Encoding UTF8 -NoTypeInformation

$mode = if ($Apply) { "ОТКЛЮЧЕНО" } else { "режим отчёта (изменений нет)" }
Write-Output "Готово [$mode]. Учёток найдено: $($report.Count). Файл: $outputFile"
