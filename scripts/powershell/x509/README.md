# Update-ADUserAltSecurityIdentity PowerShell Script

A PowerShell module to discover Client Authentication certificates in the current user’s personal store, build properly formatted X.509 `altSecurityIdentities` strings, extract corresponding user identities, and update the Active Directory `altSecurityIdentities` attribute on a specified domain controller.

> [!WARNING]  
> This script was developed to be used in a Federal PKI environment with use of DoD CAC certificates, this has NOT been extensively tested in other environments.

---

## Table of Contents

- [Features](#features)  
- [Prerequisites](#prerequisites)  
- [Installation](#installation)  
- [Usage](#usage)  
- [Functions](#functions)  
- [Examples](#examples)  
- [Error Handling & Logging](#error-handling--logging)  
- [License](#license)  

---

## Features

- **Certificate Discovery**
  - Filters all certificates in `Cert:\CurrentUser\My` whose Enhanced Key Usage includes `Client Authentication`.

- **Hex Serial Conversion**
  - Converts each certificate’s serial number into a reversed‑byte hex string.

- **X.509 Formatting**
  - Builds a `X509:<I>…<SR>…` string suitable for the AD `altSecurityIdentities` attribute.

- **User Identity Extraction**
  - Parses the certificate’s Subject CN (assumed `LAST.FIRST.MIDDLE.EDIPI`) into a `FIRST.LAST` format for AD lookup.

- **Interactive Selection**
  - Displays filtered and valid certificates and asks for one or more index values to be updated.

- **AD Update**
  - Safely updates each selected user’s `altSecurityIdentities` on the specified domain controller.

---

## Prerequisites

- Windows PowerShell 5.1 or later  
- **ActiveDirectory** PowerShell module (RSAT‑AD module)  
- Network connectivity to target domain controller  
- Permissions to run `Set-ADUser` against the specified DC  

---

## Installation

1. Clone or download this repository.  
2. Unblock the script file if downloaded from the internet:  
   ```powershell
   Unblock-File .\Update-ADUserAltSecurityIdentity.ps1
   ```
3. (Optional) Copy the script into a directory in your PowerShell module path for easy import.

---

## Usage

```powershell
.\Update-ADUserAltSecurityIdentity.ps1 [-Verbose]
```

1. **Enter Domain Controller** when prompted (FQDN).  
2. Review the table of discovered certificates.  
3. Type one or more comma‑separated index numbers to process.  
4. The script updates each user’s `altSecurityIdentities` attribute on the specified DC.

Run with `-Verbose` to see detailed progress messages.

---

## Functions

| Function                         | Description                                                                                  |
| -------------------------------- | -------------------------------------------------------------------------------------------- |
| `ConvertTo-ReversedHexString`    | Strips spaces, splits into byte pairs, reverses order, and rejoins into a hex string.       |
| `Format-AltSecurityIdentity`     | Splits and reverses the issuer DN RDNs, then builds the `X509:<I>…<SR>…` formatted string.   |
| `Get-UserIdentityFromCertSubject` | Extracts a `First.Last` identity from a certificate subject’s CN (assumes `Last.First`).    |
| `Get-ClientAuthCertificates`     | Filters certificates for Client Authentication EKU, builds serial, altSecId, and user data. |
| `Update-ADUserAltSecurityIdentity` | Performs `Set-ADUser -Replace @{ altSecurityIdentities = ... }` against the selected DC.   |

---

## Examples

Update one certificate’s corresponding user:

```powershell
.\Update-ADUserAltSecurityIdentity.ps1
# Enter Domain Controller FQDN: dc01.corp.contoso.com
# Available certificates:
#  1  user1.contoso.com  ...
#  2  user2.contoso.com  ...
# Enter comma-separated certificate index(es) to update: 2
```

Process multiple certificates:

```powershell
.\Update-ADUserAltSecurityIdentity.ps1 -Verbose
# Enter Domain Controller FQDN: dc01.corp.contoso.com
# Enter index(es): 1,3,5
```

---

## Error Handling & Logging

- Warnings are emitted for non‑even hex lengths, missing CN components, or invalid selection indices.  
- `try/catch` blocks around module import and AD updates ensure descriptive errors without script termination.  
- Use `-Verbose` to view module loading, certificate filtering, and update steps.

---

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.