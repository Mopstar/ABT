param(
    [ValidateRange(5, 600)]
    [int]$TimeoutSeconds = 45,
    [switch]$SkipPackageManagement,
    [switch]$SkipWinGet,
    [switch]$CurrentUserOnly
)

$outDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$entries = [System.Collections.Generic.List[object]]::new()

function Show-Step([string]$Message) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Cyan
}

function Add-Software {
    param(
        [string]$Name,
        [string]$Version = '',
        [string]$Publisher = '',
        [string]$InstallDate = '',
        [string]$InstallLocation = '',
        [string]$Architecture = '',
        [string]$RegistryKey = '',
        [string]$PackageId = '',
        [string]$Provider = '',
        [string]$Source = ''
    )
    if ([string]::IsNullOrWhiteSpace($Name)) { return }
    $script:entries.Add([pscustomobject]@{
        Name            = $Name.Trim()
        Version         = ([string]$Version).Trim()
        Publisher       = $Publisher
        InstallDate     = $InstallDate
        InstallLocation = $InstallLocation
        Architecture    = $Architecture
        RegistryKey     = $RegistryKey
        PackageId       = $PackageId
        Provider        = $Provider
        Source          = $Source
    })
}

function Normalize-Name([string]$Name) {
    if ($null -eq $Name) { return '' }
    return ($Name.Trim().ToLowerInvariant() -replace '[\s._-]+', '')
}

function First-Value($Items, [string]$Property) {
    foreach ($item in $Items) {
        $value = [string]$item.$Property
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
    }
    return ''
}

# 1) Registry
Show-Step '1/4 Registry: nacitam klasicke programy.'
$startCount = $entries.Count
$registryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
foreach ($path in $registryPaths) {
    foreach ($app in @(Get-ItemProperty -Path $path -ErrorAction SilentlyContinue)) {
        Add-Software -Name $app.DisplayName -Version $app.DisplayVersion `
            -Publisher $app.Publisher -InstallDate $app.InstallDate `
            -InstallLocation $app.InstallLocation -RegistryKey $app.PSPath -Source 'Registry'
    }
}
Show-Step "Registry: $($entries.Count - $startCount) zaznamu."

# 2) AppX/MSIX; run in a separate job with a timeout
Show-Step "2/4 AppX/MSIX: limit $TimeoutSeconds sekund."
$startCount = $entries.Count
if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) {
    $admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    $allUsers = [bool]($admin -and -not $CurrentUserOnly)
    if (-not $allUsers) {
        Show-Step 'AppX: nacitam jen aktualni ucet (bez -AllUsers).'
    }
    $job = $null
    try {
        $job = Start-Job -ArgumentList $allUsers -ScriptBlock {
            param([bool]$UseAllUsers)
            if ($UseAllUsers) {
                try { $apps = @(Get-AppxPackage -AllUsers -ErrorAction Stop) }
                catch {
                    Write-Warning "AppX -AllUsers selhal: $($_.Exception.Message). Pouzivam aktualni ucet."
                    $apps = @(Get-AppxPackage -ErrorAction Stop)
                }
            }
            else { $apps = @(Get-AppxPackage -ErrorAction Stop) }
            $apps | Select-Object Name, Version, Publisher, InstallLocation, Architecture, PackageFullName
        } -ErrorAction Stop
        $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
        if ($null -eq $completed) {
            Write-Warning "AppX neodpovedel do $TimeoutSeconds sekund. Tento zdroj preskakuji."
            Stop-Job -Job $job -ErrorAction SilentlyContinue
        }
        else {
            foreach ($app in @(Receive-Job -Job $job -ErrorAction Stop)) {
                Add-Software -Name $app.Name -Version ([string]$app.Version) `
                    -Publisher $app.Publisher -InstallLocation $app.InstallLocation `
                    -Architecture ([string]$app.Architecture) `
                    -PackageId $app.PackageFullName -Source 'AppX/MSIX'
            }
        }
    }
    catch { Write-Warning "AppX: $($_.Exception.Message)" }
    finally { if ($null -ne $job) { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue } }
}
else { Write-Warning 'Get-AppxPackage neni dostupny. Zdroj AppX vynechan.' }
Show-Step "AppX: $($entries.Count - $startCount) zaznamu."

# 3) PackageManagement; run in a separate job to avoid infinite waiting
if (-not $SkipPackageManagement -and (Get-Command Get-Package -ErrorAction SilentlyContinue)) {
    Show-Step "3/4 PackageManagement: limit $TimeoutSeconds sekund."
    $startCount = $entries.Count
    $job = $null
    try {
        $job = Start-Job -ScriptBlock {
            Get-Package -AllVersions -ErrorAction Stop |
                Select-Object Name, Version, ProviderName
        } -ErrorAction Stop
        $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
        if ($null -eq $completed) {
            Write-Warning "Get-Package neodpovedel do $TimeoutSeconds sekund. Tento zdroj preskakuji."
            Stop-Job -Job $job -ErrorAction SilentlyContinue
        }
        elseif ($job.State -eq 'Completed') {
            foreach ($pkg in @(Receive-Job -Job $job -ErrorAction Stop)) {
                Add-Software -Name $pkg.Name -Version ([string]$pkg.Version) `
                    -Provider ([string]$pkg.ProviderName) -Source 'PackageManagement'
            }
        }
        else {
            Receive-Job -Job $job -ErrorAction Stop | Out-Null
            Write-Warning "PackageManagement ukoncen: $($job.State)."
        }
    }
    catch { Write-Warning "PackageManagement: $($_.Exception.Message)" }
    finally { if ($null -ne $job) { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue } }
    Show-Step "PackageManagement: $($entries.Count - $startCount) zaznamu."
}
else { Show-Step '3/4 PackageManagement: preskoceno nebo nedostupne.' }

# 4) WinGet; non-interactive and limited process runtime
$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
if (-not $SkipWinGet -and $null -ne $wingetCmd) {
    Show-Step "4/4 WinGet: export, limit $TimeoutSeconds sekund."
    $startCount = $entries.Count
    $tempBase = Join-Path ([IO.Path]::GetTempPath()) "software-list-$([guid]::NewGuid().ToString('N'))"
    $tempJson = "$tempBase.json"
    $tempOut = "$tempBase.stdout.txt"
    $tempErr = "$tempBase.stderr.txt"
    $process = $null
    try {
        $wingetArguments = @(
            'export', '--output', "`"$tempJson`"", '--include-versions',
            '--accept-source-agreements', '--disable-interactivity'
        )
        $process = Start-Process -FilePath $wingetCmd.Source -ArgumentList $wingetArguments `
            -NoNewWindow -PassThru -RedirectStandardOutput $tempOut `
            -RedirectStandardError $tempErr -ErrorAction Stop

        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            Write-Warning "WinGet neodpovedel do $TimeoutSeconds sekund; preskakuji export."
            $process.Kill($true)
            $process.WaitForExit()
        }
        elseif (Test-Path -LiteralPath $tempJson) {
            $data = Get-Content -LiteralPath $tempJson -Raw -Encoding utf8 | ConvertFrom-Json
            foreach ($source in @($data.Sources)) {
                foreach ($pkg in @($source.Packages)) {
                    $id = [string]$pkg.PackageIdentifier
                    $version = [string]$pkg.Version
                    if ([string]::IsNullOrWhiteSpace($id)) { continue }
                    $fullId = Normalize-Name $id
                    $lastId = Normalize-Name (($id -split '\.')[-1])
                    $match = $entries | Where-Object {
                        $_.Version -eq $version -and (
                            (Normalize-Name $_.Name) -eq $fullId -or
                            (Normalize-Name $_.Name) -eq $lastId
                        )
                    } | Select-Object -First 1
                    $name = if ($match) { $match.Name } else { $id }
                    Add-Software -Name $name -Version $version -PackageId $id -Source 'WinGet'
                }
            }
        }
        else {
            Write-Warning 'WinGet nevytvoril JSON soubor (muze vyzadovat aktualizaci nebo konfiguraci zdroju).'
        }
    }
    catch { Write-Warning "WinGet: $($_.Exception.Message)" }
    finally {
        foreach ($path in @($tempJson, $tempOut, $tempErr)) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
        if ($null -ne $process) { $process.Dispose() }
    }
    Show-Step "WinGet: $($entries.Count - $startCount) zaznamu."
}
else { Show-Step '4/4 WinGet: preskoceno nebo nedostupne.' }

# Merge duplicates (same normalized display name and version)
Show-Step 'Slucuji duplicitni zaznamy a ukladam soubory.'
$merged = @($entries | Group-Object -Property {
    "$(Normalize-Name $_.Name)|$(([string]$_.Version).ToLowerInvariant())"
} | ForEach-Object {
    $group = @($_.Group)
    $preferred = $group |
        Sort-Object @{Expression = { if ($_.Source -eq 'Registry') { 0 } else { 1 } }} |
        Select-Object -First 1
    [pscustomobject]@{
        Name            = $preferred.Name
        Version         = $preferred.Version
        Publisher       = First-Value $group 'Publisher'
        InstallDate     = First-Value $group 'InstallDate'
        InstallLocation = First-Value $group 'InstallLocation'
        Architecture    = First-Value $group 'Architecture'
        RegistryKey     = First-Value $group 'RegistryKey'
        PackageId       = ((@($group | ForEach-Object PackageId | Where-Object { $_ } | Sort-Object -Unique)) -join '; ')
        Provider        = ((@($group | ForEach-Object Provider | Where-Object { $_ } | Sort-Object -Unique)) -join '; ')
        Sources         = ((@($group | ForEach-Object Source | Sort-Object -Unique)) -join ', ')
    }
} | Sort-Object Name, Version)


Write-Host "`nNalezeno pred sloucenim: $($entries.Count)" -ForegroundColor Cyan
Write-Host "Unikatni zaznamy: $($merged.Count)" -ForegroundColor Green

# Output of software list
Write-Host "`nSEZNAM NAINSTALOVANEHO SOFTWARU" -ForegroundColor Cyan
Write-Host "================================="

$merged |
    Format-Table Name, Version, Publisher, Sources -AutoSize -Wrap |
    Out-Host

Write-Host "`nCelkem unikatnich programu: $($merged.Count)" -ForegroundColor Green
