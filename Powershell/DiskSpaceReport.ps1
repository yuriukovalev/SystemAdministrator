<#
DiskSpaceReport.ps1
---------------------------------------------
Опрашивает список серверов и собирает отчёт по свободному месту
на логических дисках. Строки с заполнением выше порога помечаются
как WARNING — удобно для регулярного контроля.

Список серверов: либо из C:\Reports\servers.txt (по строке на хост),
либо все включённые серверные ОС из домена, если файла нет.
#>

Import-Module ActiveDirectory

$serversFile = "C:\Reports\servers.txt"
$outputFile  = "C:\Reports\DiskSpaceReport.csv"
$warnPercent = 85   # порог заполнения, %

# Источник списка серверов
if (Test-Path $serversFile) {
    $servers = Get-Content $serversFile | Where-Object { $_.Trim() }
} else {
    $servers = Get-ADComputer -Filter "Enabled -eq 'True' -and OperatingSystem -like '*Server*'" |
               Select-Object -ExpandProperty Name
}

$report = @()
foreach ($server in $servers) {
    if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
        Write-Warning "$server недоступен (ping), пропуск."
        continue
    }

    try {
        Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $server `
            -Filter "DriveType=3" -ErrorAction Stop |
            ForEach-Object {
                $usedPct = if ($_.Size) {
                    [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 1)
                } else { 0 }

                $report += [pscustomobject]@{
                    Server     = $server
                    Drive      = $_.DeviceID
                    SizeGB     = [math]::Round($_.Size / 1GB, 1)
                    FreeGB     = [math]::Round($_.FreeSpace / 1GB, 1)
                    UsedPct    = $usedPct
                    Status     = if ($usedPct -ge $warnPercent) { "WARNING" } else { "OK" }
                }
            }
    } catch {
        Write-Warning "$server — ошибка опроса: $($_.Exception.Message)"
    }
}

$report | Sort-Object Status, UsedPct -Descending |
    Export-Csv -Path $outputFile -Encoding UTF8 -NoTypeInformation

Write-Output "Готово. Дисков обработано: $($report.Count). Файл: $outputFile"
