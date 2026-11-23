# 1. Ziskani informaci o disku C:
$disk = Get-CimInstance -ClassName Win32_LogicalDisk `
    -Filter "DeviceID='C:'"

# 2. Kontrola existence disku
if ($null -eq $disk) {
    Write-Host "Disk C: nebyl nalezen." -ForegroundColor Red
    return
}

# 3. Vypis aktualniho nazvu
Write-Host "Aktualni nazev disku C: $($disk.VolumeName)"

# 4. Kontrola nazvu disku
if ($disk.VolumeName -eq "System") {
    Write-Host "Disk se jiz jmenuje System." -ForegroundColor Green
}
else {
    # 5. Prejmenovani disku
    try {
        $disk | Set-CimInstance -Property @{
            VolumeName = "System"
        } -ErrorAction Stop

        Write-Host "Disk byl prejmenovan." -ForegroundColor Green
    }
    catch {
        Write-Host "Chyba pri prejmenovani: $_" -ForegroundColor Red
        return
    }
}

# 6. Overeni vysledku
Write-Host "`nAktualni informace o disku:"

Get-CimInstance -ClassName Win32_LogicalDisk `
    -Filter "DeviceID='C:'" |
    Select-Object DeviceID, VolumeName, FileSystem |
    Format-Table -AutoSize
