<#
.SYNOPSIS
    Updates AD users’ altSecurityIdentities based on Client Authentication certificates in the current user store.

.DESCRIPTION
    - Enumerates personal certificates whose Enhanced Key Usage includes Client Authentication.
    - Converts each certificate’s serial number into a reversed hex string.
    - Formats an X.509 issuer string suitable for the AD altSecurityIdentities attribute.
    - Extracts a “first.last” user identity from the certificate subject.
    - Prompts to select certificates by index and updates the corresponding AD user(s) on the specified domain controller.

.NOTES
    Author: redkeysh
    Date  : 2025-04-22
#>

#region Module Import
Try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Verbose "ActiveDirectory module imported successfully."
}
Catch {
    Write-Error "Failed to import ActiveDirectory module: $_"
    Exit 1
}
#endregion

#region Helper Functions

function ConvertTo-ReversedHexString {
    <#
    .SYNOPSIS
        Reverses the byte order of a hexadecimal string.

    .PARAMETER HexString
        A space-delimited or contiguous hex string (e.g. "00 A1 FF" or "00A1FF").

    .OUTPUTS
        [string]  Two-character hex byte pairs in reverse order (e.g. "FFA100").

    .NOTES
        Returns $null if the input length is not even.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$HexString
    )

    $cleanHex = $HexString -Replace '\s',''
    if ($cleanHex.Length % 2) {
        Write-Warning "Input hex string must contain an even number of characters."
        return $null
    }

    $bytes = for ($i = 0; $i -lt $cleanHex.Length; $i += 2) {
        $cleanHex.Substring($i, 2)
    }

    [Array]::Reverse($bytes)
    return ($bytes -join '')
}

function Format-AltSecurityIdentity {
    <#
    .SYNOPSIS
        Builds an X509 altSecurityIdentities value for AD.

    .PARAMETER Issuer
        The certificate issuer distinguished name.

    .PARAMETER ReversedSerial
        The reversed-hex serial number (optional).

    .OUTPUTS
        [string]  Formatted X509 altSecurityIdentities entry.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Issuer,

        [Parameter()]
        [string]$ReversedSerial = ''
    )

    # Reverse the RDN sequence of the issuer
    $rdns = $Issuer -Split ',' | ForEach-Object { $_.Trim() }
    [Array]::Reverse($rdns)
    $reversedIssuer = $rdns -join ','

    $entry = "X509:<I>$reversedIssuer"
    if ($ReversedSerial) {
        $entry += "<SR>$ReversedSerial"
    }

    return $entry
}

function Get-UserIdentityFromCertSubject {
    <#
    .SYNOPSIS
        Extracts a “first.last” identity from a certificate subject’s CN.

    .PARAMETER Subject
        The certificate subject distinguished name.

    .OUTPUTS
        [string]  Username in first.last format, or $null on failure.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Subject
    )

    # Find the CN component
    $cn = ($Subject -Split ',' |
           ForEach-Object { $_.Trim() } |
           Where-Object { $_ -like 'CN=*' } |
           Select-Object -First 1) -Replace '^CN=', ''

    if (-not $cn) {
        Write-Warning "Certificate subject does not contain a CN component."
        return $null
    }

    $parts = $cn -Split '\.'
    if ($parts.Count -lt 2) {
        Write-Warning "Unexpected CN format '$cn'. Expected at least 'Last.First'."
        return $null
    }

    # Convert Last.First to First.Last
    return "$($parts[1]).$($parts[0])"
}

function Get-ClientAuthCertificates {
    <#
    .SYNOPSIS
        Retrieves user certificates with Client Authentication EKU.

    .OUTPUTS
        [pscustomobject[]]  Collection of certificate data objects.
    #>
    [CmdletBinding()]
    param ()

    $certs = Get-ChildItem -Path Cert:\CurrentUser\My
    $results = [System.Collections.Generic.List[psobject]]::new()

    foreach ($cert in $certs) {
        if ($cert.EnhancedKeyUsageList.FriendlyName -contains 'Client Authentication' -or
            $cert.EnhancedKeyUsageList.Value -contains '1.3.6.1.5.5.7.3.2') {

            $serial        = $cert.GetSerialNumberString()
            $revSerial     = ConvertTo-ReversedHexString -HexString $serial
            $altSecId      = Format-AltSecurityIdentity -Issuer $cert.Issuer -ReversedSerial $revSerial
            $userId        = Get-UserIdentityFromCertSubject -Subject $cert.Subject

            $results.Add([pscustomobject]@{
                Index             = $results.Count + 1
                Subject           = $cert.Subject
                Issuer            = $cert.Issuer
                SerialNumber      = $serial
                ReversedSerial    = $revSerial
                AltSecurityId     = $altSecId
                UserIdentity      = $userId
            })
        }
    }

    return $results
}

function Update-ADUserAltSecurityIdentity {
    <#
    .SYNOPSIS
        Updates a user’s altSecurityIdentities in AD.

    .PARAMETER UserIdentity
        The sAMAccountName or distinguished name of the user.

    .PARAMETER AltSecurityId
        The formatted altSecurityIdentities string.

    .PARAMETER DomainController
        The domain controller to target.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserIdentity,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AltSecurityId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainController
    )

    try {
        Set-ADUser -Identity $UserIdentity `
                   -Replace @{ altSecurityIdentities = @($AltSecurityId) } `
                   -Server $DomainController -ErrorAction Stop
        Write-Verbose "Updated '$UserIdentity' with altSecurityIdentities '$AltSecurityId'."
    }
    catch {
        Write-Warning "Failed to update '$UserIdentity': $_"
    }
}
#endregion

#region Main

# Prompt the administrator for the target Domain Controller. Retry with empty input.
do {
    $domainController = Read-Host -Prompt 'Enter the Domain Controller FQDN (e.g. dc01.corp.contoso.com)'
    if ([string]::IsNullOrWhiteSpace($domainController)) {
        Write-Warning 'Domain Controller cannot be blank. Please enter a valid FQDN.'
    }
} while ([string]::IsNullOrWhiteSpace($domainController))

# Retrieve and display eligible certificates
$certList = Get-ClientAuthCertificates
if (-not $certList) {
    Write-Warning 'No Client Authentication certificates found in the current user store.'
    Exit 0
}

Write-Host 'Available Client Authentication Certificates:' -ForegroundColor Cyan
$certList | Format-Table Index, UserIdentity, Subject, SerialNumber

# Select certificates to process
$selection = Read-Host -Prompt 'Enter comma-separated certificate index(es) to update'
$indexes   = $selection -Split '\s*,\s*' | ForEach-Object { [int]$_ } | Where-Object { $_ -gt 0 }

foreach ($i in $indexes) {
    $entry = $certList | Where-Object { $_.Index -eq $i }
    if ($null -eq $entry) {
        Write-Warning "Index $i is not valid; skipping."
        continue
    }
    if (-not $entry.UserIdentity) {
        Write-Warning "Cannot determine user identity for index $i; skipping."
        continue
    }

    Update-ADUserAltSecurityIdentity `
        -UserIdentity   $entry.UserIdentity `
        -AltSecurityId  $entry.AltSecurityId `
        -DomainController $domainController
}

#endregion
