# Clear the screen for easier reading.
cls

# Import ActiveDirectory to interface with AttributeEditor.
Import-Module ActiveDirectory

function MakeHex-String {
    param (
        [Parameter(Mandatory = $true)]
        [string]$HexString
    )
    
    $cleanHex = $HexString.Replace(" ", "") # Remove any spaces from the input string.
    if ($cleanHex.Length % 2 -ne 0) {
        Write-Warning "Hex string does not have an even number of characters. Aborting conversion."
        return $null
    }

    # Split the string into two-character groups.
    $bytePairs = @()
    for ($i = 0; $i -lt $cleanHex.Length; $i += 2) {
        $bytePairs += $cleanHex.Substring($i, 2)
    }

    # Reverse the array in place.
    $reversedBytePairs = $bytePairs.Clone()
    [Array]::Reverse($reversedBytePairs)
    return ($reversedBytePairs -join "")
}

# Function to generate a formatted X509 issuer string for AD altSecurityIdentities.
function Format-X509Issuer {
    param (
        [Parameter(Mandatory = $true)]
        [string]$IssuerString,
        [Parameter(Mandatory = $false)]
        [string]$ReversedSerialNumber = ""
    )

    # Split the issuer string by commas and trim spaces.
    $parts = $IssuerString.Split(",") | ForEach-Object { $_.Trim() }
    $partsClone = $parts.Clone()
    [Array]::Reverse($partsClone)
    $reversedIssuer = $partsClone -join ","
    
    $result = "X509:<I>$reversedIssuer"
    if ($ReversedSerialNumber -ne "") {
        $result += "<SR>$ReversedSerialNumber"
    }
    return $result
}

# Function to extract user identity in "first.last" format from a certificate subject.
function Get-UserIdentityFromSubject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Subject
    )
    
    $subjectParts = $Subject -split "," | ForEach-Object { $_.Trim() }
    $cnPart = $subjectParts | Where-Object { $_ -like "CN=*" } | Select-Object -First 1

    if (-not $cnPart) {
        Write-Warning "No CN found in subject."
        return $null
    }
    
    $cnValue = $cnPart -replace "^CN=", ""
    $nameParts = $cnValue -split "\."

    if ($nameParts.Count -lt 2) {
        Write-Warning "Unexpected CN format. Expected at least two dot-delimited parts."
        return $null
    }

    # Assume CN is "last.first[.more]" and convert it to "first.last".
    $userIdentity = "$($nameParts[1]).$($nameParts[0])"
    return $userIdentity
}

# Function to filter certificates that have Client Authentication as an intended usage
function Get-ClientAuthCertificates {
    $store = Get-ChildItem -Path Cert:\CurrentUser\My

    $certList = @()
    foreach ($cert in $store) {
        $clientAuthFound = $cert.EnhancedKeyUsageList |
            Where-Object { ($_.FriendlyName -match "Client Authentication") -or ($_.Value -eq "1.3.6.1.5.5.7.3.2") }

        if ($clientAuthFound) {
            # Retrieve and reverse the serial number
            $serialNumber = $cert.GetSerialNumberString()
            $reversedSerial = Reverse-HexBytes -HexString $serialNumber
            
            # Format the X509 string using the issuer
            $formatted = Format-X509Issuer -IssuerString $cert.Issuer -ReversedSerialNumber $reversedSerial
            
            # Extract a "user identity" from the certificate's subject
            $userIdentity = Get-UserIdentityFromSubject -Subject $cert.Subject
            
            # Add to list as a custom object
            $certList += [pscustomobject]@{
                Index             = $certList.Count + 1
                Subject           = $cert.Subject
                Issuer            = $cert.Issuer
                SerialNumber      = $serialNumber
                ReversedSerial    = $reversedSerial
                FormattedAltSecId = $formatted
                UserIdentity      = $userIdentity
            }
        }
    }
    return $certList
}

# Function to update AD User's altSecurityIdentities field on a specified Domain Controller.
function Update-ADUserAltSecId {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserIdentity,
        [Parameter(Mandatory = $true)]
        [string]$FormattedAltSecId,
        [Parameter(Mandatory = $true)]
        [string]$DomainController
    )
    # Update the altSecurityIdentities for the user.
    try {
        Set-ADUser -Identity $UserIdentity -Replace @{altSecurityIdentities=@($FormattedAltSecId)} -Server $DomainController
        Write-Host "Updated user '$UserIdentity' with altSecurityIdentities: $FormattedAltSecId" -ForegroundColor Green
    } catch {
        Write-Host "Failed to update user '$UserIdentity'. Error: $_" -ForegroundColor Red
    }
}

##############################################
# MAIN SCRIPT LOGIC
##############################################

# Choose the Domain Controller to use. You can hard-code or prompt for one.
$domainController = Read-Host

# Get all valid certificates with Client Authentication EKU.
$clientCerts = Get-ClientAuthCertificates

if ($clientCerts.Count -eq 0) {
    Write-Host "No applicable Client Authentication certificates found in your personal store." -ForegroundColor Yellow
    Exit
}

# Display the retrieved certificates in a table.
Write-Host "The following certificates were found:" -ForegroundColor Cyan
$clientCerts | Format-Table Index, UserIdentity, Subject, SerialNumber

# Interactive mode: ask for certificate index number(s)
$selection = Read-Host "Enter a comma-separated list of certificate index numbers to update"
$selectedIndexes = $selection -split "\s*,\s*" | ForEach-Object { [int]$_ }
        
foreach ($index in $selectedIndexes) {
    $certEntry = $clientCerts | Where-Object { $_.Index -eq $index }
    if ($certEntry -ne $null) {
        if (-not $certEntry.UserIdentity) {
            Write-Host "Unable to determine user identity for certificate index $index; skipping." -ForegroundColor Yellow
            continue
        }
        Update-ADUserAltSecId -UserIdentity $certEntry.UserIdentity -FormattedAltSecId $certEntry.FormattedAltSecId -DomainController $domainController
    }
    else {
        Write-Host "No certificate found with index $index." -ForegroundColor Red
    }
        
}
