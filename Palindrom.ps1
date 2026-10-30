
param(
    [string]$Text
)

# Nacteni textu, pokud nebyl predan argument
if ([string]::IsNullOrWhiteSpace($Text)) {
    $Text = Read-Host "Zadejte text"
}

# Prevedeni na mala pismena
$upravenyText = $Text.ToLowerInvariant()

# Odstraneni diakritiky
$upravenyText = $upravenyText.Normalize(
    [Text.NormalizationForm]::FormD
)
$upravenyText = $upravenyText -replace '\p{Mn}', ''

# Odstraneni mezer a interpunkce
$upravenyText = $upravenyText -replace '[^\p{L}\p{N}]', ''

# Obraceni poradi znaku
$znaky = [char[]]$upravenyText
[array]::Reverse($znaky)
$obracenyText = -join $znaky

# Overeni palindromu
if ($upravenyText.Length -eq 0) {
    Write-Host "Text neobsahuje zadna pismena ani cislice."
}
elseif ($upravenyText -ceq $obracenyText) {
    Write-Host "Text je palindrom!" -ForegroundColor Green
}
else {
    Write-Host "Text neni palindrom." -ForegroundColor Red
}
