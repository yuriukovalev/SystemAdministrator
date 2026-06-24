<#
ExportOUTree.ps1
---------------------------------------------
Выгружает структуру организационных подразделений (OU) домена
в виде дерева с отступами и количеством объектов в каждом OU.
Полезно для документирования и проверки структуры AD.
#>

Import-Module ActiveDirectory

$outputFile = "C:\Reports\OU_Tree.txt"
$domainDN = (Get-ADDomain).DistinguishedName

# Считаем уровень вложенности по числу "OU=" в DistinguishedName
function Get-OUDepth([string]$dn) {
    ([regex]::Matches($dn, 'OU=')).Count
}

$lines = @()
Get-ADOrganizationalUnit -Filter * -Properties CanonicalName |
    Sort-Object CanonicalName |
    ForEach-Object {
        $depth  = Get-OUDepth $_.DistinguishedName
        $indent = "  " * ($depth - 1)

        # Количество объектов непосредственно в этом OU
        $count = (Get-ADObject -SearchBase $_.DistinguishedName -SearchScope OneLevel `
                    -Filter 'objectClass -eq "user" -or objectClass -eq "computer"').Count

        $lines += "{0}{1}  [{2}]" -f $indent, $_.Name, $count
    }

$lines | Out-File -Encoding UTF8 $outputFile
Write-Output "Готово. OU выгружено: $($lines.Count). Файл: $outputFile"
