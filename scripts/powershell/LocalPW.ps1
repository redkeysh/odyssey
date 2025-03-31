
# Check if the script is running with elevated privileges
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    # Relaunch the script with elevated privileges
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Write-Host "Restarted shell as administrator"
    exit
}

# Define the username and the new password
#Write-Host "Please enter username:"
#$username = Read-Host
#Write-Host "Please enter password:"
#$password = Read-Host -AsSecureString


$username = "<change_me>"
$encrypted = "<pre-encrpted-string>"
$password = ConvertTo-SecureString $encrypted 

# Get the local user account
$userAccount = Get-LocalUser -Name $username

# Check if the user account exists
if ($userAccount) {
    # Change the password
    $userAccount | Set-LocalUser -Password $password
    Write-Host "Password for user '$username' has been changed successfully."
} else {
    Write-Host "User account '$username' does not exist."
}
