<#
PrivilegedGroupMembers.ps1
---------------------------------------------
Аудит состава привилегированных групп Active Directory.
Выгружает всех членов критичных групп (включая вложенные) в CSV —
удобно для регулярной проверки, кто имеет повышенные права в домене.
#>

Import-Module ActiveDirectory

# Критичные группы для аудита
$groups = @(
    "Domain Admins",
    "Enterprise Admins",
    "Schema Admins",
    "Administrators",
    "Account Operators",
    "Backup Operators"
)

$outputFile = "C:\Reports\PrivilegedGroupMembers.csv"
$report = @()

foreach ($groupName in $groups) {
    $group = Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue
    if (-not $group) {
        Write-Warning "Группа '$groupName' не найдена, пропуск."
        continue
    }

    # -Recursive разворачивает вложенные группы до конечных пользователей
    Get-ADGroupMember -Identity $group -Recursive |
        Where-Object { $_.objectClass -eq 'user' } |
        ForEach-Object {
            $user = Get-ADUser $_ -Properties Enabled, LastLogonDate
            $report += [pscustomobject]@{
                Group         = $groupName
                SamAccountName = $user.SamAccountName
                Name          = $user.Name
                Enabled       = $user.Enabled
                LastLogonDate = $user.LastLogonDate
            }
        }
}

$report | Sort-Object Group, SamAccountName |
    Export-Csv -Path $outputFile -Encoding UTF8 -NoTypeInformation

Write-Output "Готово. Найдено записей: $($report.Count). Файл: $outputFile"
