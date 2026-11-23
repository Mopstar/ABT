
# Cesta k nastaveni prihlasovaci obrazovky
$path = 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard'

# Nacteni aktualni hodnoty
$value = Get-ItemPropertyValue -Path $path -Name 'InitialKeyboardIndicators'

Write-Host "Aktualni hodnota: $value"

# Kontrola, zda je Num Lock nastaven jako zapnuty
if (([long]$value -band 2) -ne 0) {
    Write-Host "Num Lock je jiz nastaven jako zapnuty." -ForegroundColor Green
}
else {
    Write-Host "Num Lock neni nastaven jako zapnuty." -ForegroundColor Yellow

    # Zapnuti Num Locku se zachovanim ostatnich priznaku
    $newValue = [string](([long]$value) -bor 2)

    Set-ItemProperty -Path $path -Name 'InitialKeyboardIndicators' -Value $newValue

    Write-Host "Nastaveni Num Locku bylo upraveno." -ForegroundColor Green
}

# Zaverecna kontrola
Get-ItemProperty -Path $path -Name 'InitialKeyboardIndicators'
