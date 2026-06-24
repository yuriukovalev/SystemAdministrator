param(
    [switch]$PerOU,
    [string]$ExportCsv,
    [switch]$DebugSample
)

try { Import-Module ActiveDirectory -ErrorAction Stop }
catch { Write-Error "Нет модуля ActiveDirectory (RSAT). $_"; return }

# === Базовые коды (порядок = приоритет) ===
$CodeMap = [ordered]@{
    'BOSE' = 'БОС'
    'BOS'  = 'БОС'
    'BIS'  = 'БОС'
    'BUD'  = 'БУД'
    'BKP'  = 'БМИ'
    'BMI'  = 'БМИ'
    'BIF'  = 'БМИ'
    'ORF'  = 'ОРФ'
    'HQD'  = 'Штаб'
    'BO'   = 'Обмен' # справа не буква
}

# Сайты -> названия городов
$CityMap = [ordered]@{
    'EKB'='Екатеринбург'
    'MSK'='Москва'
    'SPB'='Санкт-Петербург'
    'TMN'='Тюмень'
    'NSK'='Новосибирск'
    'OMS'='Омск'
    'KRG'='Курган'
    'SRG'='Сургут'
    'LPK'='Липецк'
    'CHL'='Челябинск'
}

$W='[\p{L}\p{Nd}]'  # юникодные буквы/цифры

# === Правила (сверху — самый высокий приоритет) ===
$Rules = New-Object System.Collections.Generic.List[object]

# 0) Веточные правила: BSZ/FBSZ, BOS/BIS/BOSE, BUD — помечаем филиал + тип
foreach ($kvp in $CityMap.GetEnumerator()) {
    $site  = [regex]::Escape($kvp.Key)
    $city  = $kvp.Value

    # BSZ/FBSZ -> "Филиал <город>"
    $Rules.Add([pscustomobject]@{
        Code  = "$($kvp.Key)-BSZ"
        Label = "Филиал $city"
        Regex = [regex]::new("(?i)^$site-(?:F?BSZ)(?!$W)",
            [System.Text.RegularExpressions.RegexOptions]::Compiled -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    }) | Out-Null

    # BOS/BIS/BOSE -> "Филиал БОС <город>"
    $Rules.Add([pscustomobject]@{
        Code  = "$($kvp.Key)-BOS*"
        Label = "Филиал БОС $city"
        Regex = [regex]::new("(?i)^$site-(?:BOS|BIS|BOSE)(?!$W)",
            [System.Text.RegularExpressions.RegexOptions]::Compiled -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    }) | Out-Null

    # BUD -> "Филиал БУД <город>"
    $Rules.Add([pscustomobject]@{
        Code  = "$($kvp.Key)-BUD"
        Label = "Филиал БУД $city"
        Regex = [regex]::new("(?i)^$site-(?:BUD)(?!$W)",
            [System.Text.RegularExpressions.RegexOptions]::Compiled -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    }) | Out-Null
}

# 1) HQDP* -> Штаб
$Rules.Add([pscustomobject]@{
    Code  = 'HQDP+'
    Label = 'Штаб'
    Regex = [regex]::new("(?i)(?<!$W)HQDP[\p{L}\p{Nd}]*",
        [System.Text.RegularExpressions.RegexOptions]::Compiled -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
}) | Out-Null

# 2) Остальные коды (с границами)
foreach ($kvp in $CodeMap.GetEnumerator()) {
    $code  = [regex]::Escape($kvp.Key)
    $label = $kvp.Value
    $pattern = switch ($kvp.Key) {
        'BO'  { "(?i)$code(?![\p{L}])" }     # не зацепит BOS/BOSE
        'HQD' { "(?i)(?<!$W)$code(?!$W)" }   # строгие границы HQD
        default { "(?i)(?<!$W)$code(?!$W)" }
    }
    $Rules.Add([pscustomobject]@{
        Code=$kvp.Key; Label=$label;
        Regex=[regex]::new($pattern,
            [System.Text.RegularExpressions.RegexOptions]::Compiled -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    }) | Out-Null
}

# (Важное изменение) — НЕТ общего правила "BSZ*" → «БСЗ». Убрано по твоей просьбе.

# === Выборка AD (Enabled=True) ===
$domainDN  = (Get-ADDomain).DistinguishedName
$computers = Get-ADComputer -Filter "Enabled -eq 'True'" -SearchBase $domainDN -SearchScope Subtree `
    -Properties Name,sAMAccountName,Enabled,DistinguishedName -ResultPageSize 2000 -ResultSetSize $null
if (-not $computers) { Write-Host "В домене нет включённых компьютеров." -ForegroundColor Yellow; return }

# === Сводки ===
$summaryCounts = [ordered]@{}
$perOuCounts   = @{}
$unmatched     = New-Object System.Collections.Generic.List[object]
$matchedByRule = @{}

foreach ($r in $Rules) {
    if (-not $summaryCounts.Contains($r.Label)) { $summaryCounts[$r.Label] = 0 }
    if (-not $matchedByRule.ContainsKey($r.Code)) { $matchedByRule[$r.Code] = New-Object System.Collections.Generic.List[string] }
}
$summaryCounts['Прочие'] = 0

foreach ($c in $computers) {
    $baseName = if ($c.sAMAccountName) { $c.sAMAccountName.TrimEnd('$') } else { $c.Name }
    $dn       = $c.DistinguishedName

    # Верхний OU
    $parentDN = ($dn -replace '^CN=[^,]+,', '')
    $topOU    = ($parentDN -split ',') | Where-Object { $_ -like 'OU=*' } | Select-Object -First 1
    $topOU    = if ($topOU) { $topOU -replace '^OU=', '' } else { '—' }

    # Классификация
    $label = 'Прочие'; $fired = $null
    foreach ($r in $Rules) {
        if ($r.Regex.IsMatch($baseName)) { $label = $r.Label; $fired=$r.Code; break }
    }

    # Fallback по OU: Conf/HQD* → Штаб
    if ($label -eq 'Прочие') {
        if ($topOU -match '^(?i)Conf$') { $label = 'Штаб' }
        elseif ($topOU -match '^(?i)HQD[\p{L}]*$') { $label = 'Штаб' }
    }

    $summaryCounts[$label]++

    if ($PerOU) {
        if (-not $perOuCounts.ContainsKey($topOU)) {
            $perOuCounts[$topOU] = @{}
            foreach ($l in $summaryCounts.Keys) { $perOuCounts[$topOU][$l] = 0 }
        }
        $perOuCounts[$topOU][$label]++
    }

    if ($DebugSample -and $fired -and $matchedByRule[$fired].Count -lt 10) {
        $matchedByRule[$fired].Add($baseName) | Out-Null
    }

    if ($label -eq 'Прочие' -and $unmatched.Count -lt 5000) {
        $unmatched.Add([pscustomobject]@{ Name=$baseName; TopOU=$topOU; DN=$dn }) | Out-Null
    }
}

# === Вывод ===
Write-Host "`n=== Итоги по домену (Enabled=True) ===" -ForegroundColor Cyan
$total = 0
$rows = foreach ($k in $summaryCounts.Keys) {
    $count = [int]$summaryCounts[$k]; $total += $count
    [pscustomobject]@{ Категория=$k; Количество=$count }
}
$rows | Sort-Object Количество -Descending | Format-Table -AutoSize
Write-Host ("Всего компьютеров: {0}" -f $total) -ForegroundColor Green

if ($DebugSample) {
    Write-Host "`n=== Примеры совпадений по правилам ===" -ForegroundColor Yellow
    foreach ($r in $Rules) {
        $list = $matchedByRule[$r.Code]
        if ($list.Count -gt 0) {
            Write-Host ("`n{0} → {1}" -f $r.Code, $r.Label) -ForegroundColor Magenta
            $list | Select-Object -First 10 | ForEach-Object { "  $_" }
        }
    }
    if ($unmatched.Count -gt 0) {
        Write-Host "`nНесовпавшие (первые 30):" -ForegroundColor Yellow
        $unmatched | Select-Object -First 30 | Format-Table -AutoSize
    }
}

# === Экспорт (опционально) ===
if ($ExportCsv) {
    $base = $ExportCsv.TrimEnd('.csv')
    $rows      | Export-Csv -Path ($base + '-summary.csv')   -NoTypeInformation -Encoding UTF8
    $unmatched | Export-Csv -Path ($base + '-unmatched.csv') -NoTypeInformation -Encoding UTF8
    if ($PerOU) {
        $flat = foreach ($ou in $perOuCounts.Keys) {
            foreach ($label in $summaryCounts.Keys) {
                [pscustomobject]@{ OU=$ou; Категория=$label; Количество=[int]$perOuCounts[$ou][$label] }
            }
        }
        $flat | Export-Csv -Path ($base + '-perou.csv') -NoTypeInformation -Encoding UTF8
    }
    Write-Host ("Экспортировано: {0}-summary.csv, {0}-unmatched.csv{1}" -f $base, $(if($PerOU){", {0}-perou.csv" -f $base})) -ForegroundColor Green
}