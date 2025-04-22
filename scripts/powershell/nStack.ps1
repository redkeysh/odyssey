<#
       _____ _             _    
      /  ___| |           | |   
 _ __ \ `--.| |_ __ _  ___| | __
| '_ \ `--. \ __/ _` |/ __| |/ /
| | | /\__/ / || (_| | (__|   < 
|_| |_\____/ \__\__,_|\___|_|\_\

##################################################
# nStack - Simple local stack management script  #
# Developed by Hunter Stokes                     #
##################################################
#>

$sn = (Get-WmiObject -class win32_bios).SerialNumber
if($sn -match "MXL") { $sn = $sn.Replace("MXL", "") } 

$date = Get-Date -Format "MMddyyyy.HHmmss"
$logPath = "\\server\share\Software Deployments\Logs\nstack-$($sn)-$($date).log"

Import-Module -DisableNameChecking "\\server\share\Software Deployments\mod\New-FolderForced.psm1"

# Start transcript and logging to remote path
Start-Transcript -path $logPath -append

Write-Output "#### Checking if asset name matches shipboard naming scheme. ####"

$expectedName = "STANDARD_PC_IDENTIFIER-$($sn)"
$actualName = Get-Content env:computername

if($expectedName -eq $actualName) {
    Write-Output "#### Computer name is $($actualName), which appears to match the expected value of: $($expectedName) - Please make sure this is correct. ####" 
} else {
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("WARNING! The computer name doesn't match the shipboard naming scheme!`n`nActual Name: $($actualName)`n`nExpected Name: $($expectedName)",0,"Warning",0x1)
}

###

Write-Output "Running WSUS / Update Fix Script"
net stop bits
net stop wuauserv
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v AccountDomainSid /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v PingID /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v SusClientId /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v SusClientIDValidation /f
Remove-Item "C:\WINDOWS\SoftwareDistribution" -Recurse -force -ErrorAction SilentlyContinue
net start bits
net start wuauserv
wuauclt /resetauthorization /detectnow
(New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()

###

# Import the remote versioning file
$versionFile = Import-Csv -Path "\\server\share\Software Deployments\Config\versions.csv"

# Set the empty hashtables
$remotePackages = @{}
$remoteInstallers = @{}
$localPackages = @{}

<#
# Add the remote versioning into remotePackages hash table.
foreach ($package in $versionFile) { $remotePackages.add($package.Name, $package.Version) }

# Add the remote versioning COMMAND into remotePackages hash table.
foreach ($package in $versionFile) { $remoteInstallers.add($package.Name, $package.Installer) }

#Loop through remotePackages hash table, using keys to compare to local install.
foreach ($remotePackage in $remotePackages.Keys) {
    $localPackage = Get-Package *$remotePackage*
    
    # Check if package is installed    
    if ($localPackage.Name -match $remotePackage.Name) {
       
        # Package is installed, add to localPackages hash table, using REMOTE package name (in cases where local installs of packages include versions, such as Java 8 U391)
        $localPackages.Add($remotePackage, $localPackage.Version)
    }
}


foreach ($localPackage in $localPackages.Keys) {
    
    [Version]$localVersion = [String] $localPackages[$localPackage]
    [Version]$remoteVersion = [String] $remotePackages[$localPackage]

    if($localVersion -lt $remoteVersion) {
       
        #$installer = Get-ChildItem -Path $base -Name $localPackage*

        Write-Output "##############################################################################################"
        Write-Output "#### INFO: $($localPackage) - Version: $($localVersion) is outdated according to the nStack repository. Latest version is $($remoteVersion) ####" 
        Write-Output "##############################################################################################"

        $cmd = $remoteInstallers[$localPackage].Replace("'", "")
        $expression = "& $($cmd)"
        Invoke-Expression $expression
    }
}
#>
Write-Output "#### Running GroupPolicy Fix ####"
if (Test-Path "C:\Windows\System32\GroupPolicy\Machine\registry.bak") { Remove-Item "C:\Windows\System32\GroupPolicy\Machine\registry.bak" }
if (Test-Path "C:\Windows\System32\GroupPolicy\Machine\registry.pol") { Rename-Item "C:\Windows\System32\GroupPolicy\Machine\registry.pol" "C:\Windows\System32\GroupPolicy\Machine\registry.bak" }

gpupdate /force

#################################################
# Courtesy of W4RH4WK on GitHub 
# https://github.com/W4RH4WK/Debloat-Windows-10/
#################################################

Write-Output "#### RUNNING WINDOWS 10 DEBLOAT ####"
$apps = @(
    # default Windows 10 apps
    "Microsoft.549981C3F5F10" #Cortana
    "Microsoft.3DBuilder"
    "Microsoft.Appconnector"
    "Microsoft.BingFinance"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.BingTranslator"
    "Microsoft.BingWeather"
    "Microsoft.FreshPaint"
    "Microsoft.GamingServices"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftPowerBIForWindows"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MinecraftUWP"
    "Microsoft.NetworkSpeedTest"
    "Microsoft.Office.OneNote"
    "Microsoft.People"
    "Microsoft.Print3D"
    "Microsoft.SkypeApp"
    "Microsoft.Wallet"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCamera"
    "microsoft.windowscommunicationsapps"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsPhone"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"

    # Threshold 2 apps
    "Microsoft.CommsPhone"
    "Microsoft.ConnectivityStore"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.Messaging"
    "Microsoft.Office.Sway"
    "Microsoft.OneConnect"
    "Microsoft.WindowsFeedbackHub"

    # Creators Update apps
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MSPaint"

    #Redstone apps
    "Microsoft.BingFoodAndDrink"
    "Microsoft.BingHealthAndFitness"
    "Microsoft.BingTravel"
    "Microsoft.WindowsReadingList"

    # Redstone 5 apps
    "Microsoft.MixedReality.Portal"
    "Microsoft.ScreenSketch"
    "Microsoft.XboxGamingOverlay"
)

$appxprovisionedpackage = Get-AppxProvisionedPackage -Online

foreach ($app in $apps) {
    #Write-Output "Attempting to remove: $app"
    if(Get-AppxPackage -Name $app -AllUsers) { Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage; Write-Host "Removed $($app)" }

    ($appxprovisionedpackage).Where( {$_.DisplayName -EQ $app}) |
        Remove-AppxProvisionedPackage -Online
}

# Prevents Apps from re-installing
$cdm = @(
    "ContentDeliveryAllowed"
    "FeatureManagementEnabled"
    "OemPreInstalledAppsEnabled"
    "PreInstalledAppsEnabled"
    "PreInstalledAppsEverEnabled"
    "SilentInstalledAppsEnabled"
    "SubscribedContent-314559Enabled"
    "SubscribedContent-338387Enabled"
    "SubscribedContent-338388Enabled"
    "SubscribedContent-338389Enabled"
    "SubscribedContent-338393Enabled"
    "SubscribedContentEnabled"
    "SystemPaneSuggestionsEnabled"
)

New-FolderForced -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
foreach ($key in $cdm) {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" $key 0
}

New-FolderForced -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" "AutoDownload" 2

# Prevents "Suggested Applications" returning
New-FolderForced -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1

Stop-Transcript