# Nastaveni
$printerName = "Fax"
$newLocation = "Kancelar 101"

# 1. Zjisteni vlastnosti tridy Win32_Printer
Write-Host "`nVlastnosti tridy Win32_Printer:" -ForegroundColor Cyan

Get-CimClass -ClassName Win32_Printer |
    Select-Object -ExpandProperty CimClassProperties |
    Select-Object Name, CimType |
    Format-Table -AutoSize

# 2. Vypis dostupnych tiskaren
Write-Host "`nDostupne tiskarny:" -ForegroundColor Cyan

Get-CimInstance -ClassName Win32_Printer |
    Select-Object Name, Location |
    Format-Table -AutoSize

# 3. Vyhledani faxu
$printer = Get-CimInstance -ClassName Win32_Printer |
    Where-Object { $_.Name -eq $printerName }

if ($null -eq $printer) {
    Write-Host "Tiskarna '$printerName' nebyla nalezena." -ForegroundColor Yellow
    return
}

# 4. Zmena umisteni
try {
    $printer | Set-CimInstance -Property @{
        Location = $newLocation
    } -ErrorAction Stop

    Write-Host "`nUmisteni bylo zmeneno." -ForegroundColor Green
}
catch {
    Write-Host "Chyba pri zmene umisteni: $_" -ForegroundColor Red
    return
}

# 5. Overeni zmeny
Write-Host "`nAktualni umisteni tiskarny:" -ForegroundColor Cyan

Get-CimInstance -ClassName Win32_Printer |
    Where-Object { $_.Name -eq $printerName } |
    Select-Object Name, Location |
    Format-Table -AutoSize
