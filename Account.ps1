# 1. Ziskani lokalnich uctu
$users = @(Get-LocalUser)

Write-Host "`n=== VSECHNY LOKALNI UCTY ===" -ForegroundColor Cyan
$users | Format-Table Name, Enabled, LastLogon -AutoSize

# 2. Nepouzite ucty - Get-LocalUser
Write-Host "`n=== NEPOUZITE UCTY (PowerShell) ===" -ForegroundColor Cyan

$unusedPS = @(
    $users | Where-Object { $null -eq $_.LastLogon }
)

if ($unusedPS.Count -gt 0) {
    $unusedPS | Format-Table Name, Enabled, LastLogon -AutoSize
}
else {
    Write-Host "Zadne ucty bez evidovaneho prihlaseni."
}

# 3. Nepouzite ucty - CIM
Write-Host "`n=== NEPOUZITE UCTY (CIM) ===" -ForegroundColor Cyan

$cimUsers = @(
    Get-CimInstance Win32_UserAccount -Filter "LocalAccount=True"
)

$profiles = @(
    Get-CimInstance Win32_NetworkLoginProfile
)

$unusedCIM = @(
    foreach ($user in $cimUsers) {

        $accountName = "$($user.Domain)\$($user.Name)"

        $profile = $profiles |
            Where-Object { $_.Name -eq $accountName } |
            Select-Object -First 1

        if ($null -ne $profile -and
            $profile.NumberOfLogons -eq 0 -and
            $null -eq $profile.LastLogon) {

            [PSCustomObject]@{
                Name           = $user.Name
                NumberOfLogons = $profile.NumberOfLogons
                LastLogon      = $profile.LastLogon
            }
        }
    }
)

if ($unusedCIM.Count -gt 0) {
    $unusedCIM | Format-Table -AutoSize
}
else {
    Write-Host "Zadne odpovidajici ucty nebyly nalezeny."
}

# 4. Uzamcene ucty - CIM
Write-Host "`n=== UZAMCENE UCTY (CIM) ===" -ForegroundColor Cyan

$lockedCIM = @(
    $cimUsers | Where-Object { $_.Lockout -eq $true }
)

if ($lockedCIM.Count -gt 0) {
    $lockedCIM |
        Select-Object Name, Domain, Lockout |
        Format-Table -AutoSize
}
else {
    Write-Host "Zadne uzamcene ucty."
}

# 5. Uzamcene ucty - PowerShell + .NET
Write-Host "`n=== UZAMCENE UCTY (PowerShell/.NET) ===" -ForegroundColor Cyan

try {
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement -ErrorAction Stop

    $context = [System.DirectoryServices.AccountManagement.PrincipalContext]::new(
        [System.DirectoryServices.AccountManagement.ContextType]::Machine,
        $env:COMPUTERNAME
    )

    try {
        $lockedPS = @(
            foreach ($user in $users) {
                $principal = $null

                try {
                    $principal = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity(
                        $context,
                        [System.DirectoryServices.AccountManagement.IdentityType]::SamAccountName,
                        $user.Name
                    )

                    if ($null -ne $principal -and $principal.IsAccountLockedOut()) {
                        [PSCustomObject]@{
                            Name   = $user.Name
                            Locked = $true
                        }
                    }
                }
                catch {
                    Write-Warning "Nelze overit ucet $($user.Name): $_"
                }
                finally {
                    if ($null -ne $principal) {
                        $principal.Dispose()
                    }
                }
            }
        )

        if ($lockedPS.Count -gt 0) {
            $lockedPS | Format-Table -AutoSize
        }
        else {
            Write-Host "Zadne uzamcene ucty nebyly zjisteny."
        }
    }
    finally {
        $context.Dispose()
    }
}
catch {
    Write-Warning "Kontrola pomoci .NET neni dostupna: $_"
}

Write-Host "`n=== KONTROLA DOKONCENA ===" -ForegroundColor Green
