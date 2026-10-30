
param(
    [Parameter(Position = 0)]
    [string]$Text
)

# Pokud nebyl text predan jako argument
if ($null -eq $Text) {
    $Text = Read-Host "Zadejte text"
}

# Pocet znaku vcetne mezer
$znakySMezerami = $Text.Length

# Pocet znaku bez bilych znaku
$znakyBezMezer = ($Text -replace '\s', '').Length

# Pocet samohlasek vcetne ceske diakritiky
$samohlasky = ([regex]::Matches(
    $Text, '(?i)[aeiouyáéěíóúůý]'
)).Count

# Pocet slov
$slova = ([regex]::Matches($Text, '\S+')).Count

# Vypis vysledku
Write-Host "---------------------------"
Write-Host "Statistika textu:"
Write-Host "Znaky s mezerami: $znakySMezerami"
Write-Host "Znaky bez mezer:  $znakyBezMezer"
Write-Host "Pocet samohlasek: $samohlasky"
Write-Host "Pocet slov:       $slova"
Write-Host "---------------------------"
