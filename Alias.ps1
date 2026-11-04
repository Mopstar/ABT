
# 1. Vytvoreni aliasu
Set-Alias -Name np -Value notepad.exe
Set-Alias -Name ct -Value control.exe

Write-Host "Vytvorene aliasy:" -ForegroundColor Cyan
Get-Alias np, ct

# 2. Ziskani aliasu pro zalohovani
$aliases = Get-Alias np, ct |
    Select-Object Name, Definition

# 3. Zaloha do JSON
$aliases | ConvertTo-Json |
    Set-Content -Path "$PSScriptRoot\aliasy.json"

# 4. Zaloha do XML
$aliases | Export-Clixml -Path "$PSScriptRoot\aliasy.xml"

Write-Host "`nZalohy byly vytvoreny." -ForegroundColor Green

# 5. Odstraneni aliasu
Remove-Item Alias:np, Alias:ct

Write-Host "`nKontrola odstraneni:"
Test-Path Alias:np
Test-Path Alias:ct

# 6. Obnoveni z JSON
Get-Content "$PSScriptRoot\aliasy.json" -Raw |
    ConvertFrom-Json |
    ForEach-Object {
        Set-Alias -Name $_.Name -Value $_.Definition
    }

Write-Host "`nObnoveno z JSON:" -ForegroundColor Green
Get-Alias np, ct

# 7. Opetovne odstraneni aliasu
Remove-Item Alias:np, Alias:ct

Write-Host "`nKontrola druheho odstraneni:"
Test-Path Alias:np
Test-Path Alias:ct

# 8. Obnoveni z XML
Import-Clixml "$PSScriptRoot\aliasy.xml" |
    ForEach-Object {
        Set-Alias -Name $_.Name -Value $_.Definition
    }

Write-Host "`nObnoveno z XML:" -ForegroundColor Green
Get-Alias np, ct
