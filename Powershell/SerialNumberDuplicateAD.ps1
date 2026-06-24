# Получаем список всех включенных компьютеров с LastLogonTimeStamp и описанием из всего домена
$computers = Get-ADComputer -Properties LastLogonTimeStamp, Description, Enabled `
    -Filter { Enabled -eq $true }

# Извлекаем серийные номера и добавляем их в список
$serialNumbers = @()

foreach ($computer in $computers) {
    # Проверяем, что поле Description существует и не содержит указанные строки
    if ($computer.Description -and 
        $computer.Description -notmatch 'System Serial Number' -and 
        $computer.Description -notmatch 'Default string') {
        
        Write-Host "Processing Description: $($computer.Description)"  # Выводим описание для отладки
        
        # Используем регулярное выражение для поиска серийных номеров
        if ($computer.Description -match '^[^|]*\|\s*[^|]*\|\s*([^|]*)\s*\|') {
            $serialNumber = $matches[1] -replace '\s', ''  # Удаляем возможные пробелы
            $serialNumbers += [PSCustomObject]@{
                ComputerName = $computer.Name
                Description  = $computer.Description
                SerialNumber = $serialNumber
            }
            Write-Host "Found Serial Number: $serialNumber for Computer: $($computer.Name)"  # Отладочная информация
        } else {
            Write-Host "No Serial Number found in: $($computer.Description)"  # Если не нашли серийный номер
        }
    } else {
        Write-Host "Skipping Description due to match for 'System Serial Number' or 'Default string' or empty description."
    }
}

# Группируем по серийному номеру и смотрим на количество
$groupedSerials = $serialNumbers | Group-Object SerialNumber | Where-Object { $_.Count -gt 1 }

# Проверяем, чтобы активных устройств (групп) было больше 1
$activeDevices = $groupedSerials | Where-Object { $_.Count -gt 1 } 

# Форматируем результаты для экспорта в CSV
$results = $activeDevices | ForEach-Object {
    $_.Group | Select-Object ComputerName, Description, SerialNumber
}

# Экспортируем в CSV
$results | Export-CSV c:\ps\duplicate_serial_numbers.csv -NoTypeInformation

# Сообщение о завершении
if ($results) {
    Write-Host "Duplicate serial numbers exported to c:\ps\duplicate_serial_numbers.csv"
} else {
    Write-Host "No duplicate serial numbers found."
}