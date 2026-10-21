
$colors = [Enum]::GetValues([ConsoleColor])

foreach ($color in $colors) {
    $name = $color.ToString()

    $textColor = if ($color -in @(
        'Gray', 'Green', 'Cyan', 'Yellow', 'White'
    )) {
        'Black'
    }
    else {
        'White'
    }

    # Sloupec 1 - nazvy barev
    Write-Host $name.PadRight(15) -ForegroundColor Gray -NoNewline

    # Sloupec 2 - barevny text
    Write-Host $name.PadRight(15) -ForegroundColor $color -NoNewline

    # Sloupec 3 - barevne pozadi
    Write-Host $name.PadRight(15) -ForegroundColor $textColor -BackgroundColor $color
}
