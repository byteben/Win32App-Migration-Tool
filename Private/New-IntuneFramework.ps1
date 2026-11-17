<#
.Synopsis
Created on:   24/03/2024
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     New-IntuneFramework.ps1

.Description
Builds the JSON body for a Win32 app (Microsoft Graph beta win32LobApp) and writes a copy to
Win32appBody.json for reference.
Parameter descriptions reference https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-add

Graph values used (Microsoft Graph beta win32LobAppInstallExperience / win32LobAppReturnCode):
  installExperience.runAsAccount           system | user
  installExperience.deviceRestartBehavior  basedOnReturnCode | allow | suppress | force
  installExperience.maxRunTimeInMinutes    Int32, default 60
  returnCodes[].type                       success | failed | softReboot | hardReboot | retry

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function.

.PARAMETER Name
The app name as it appears in the Company Portal

.PARAMETER Description
The app description for the Company Portal

.PARAMETER Publisher
The publisher name

.PARAMETER AppVersion
The display version

.PARAMETER InformationURL
The information URL

.PARAMETER PrivacyURL
The privacy URL

.PARAMETER Notes
Notes for the app

.PARAMETER LargeIcon
The base64 value of the app icon (PNG)

.PARAMETER Path
Folder to write Win32appBody.json to

.PARAMETER FileName
The .intunewin file name from the package metadata

.PARAMETER SetupFile
The setup file name from the package metadata

.PARAMETER InstallCommandLine
The install command line

.PARAMETER UninstallCommandLine
The uninstall command line. When empty, UninstallCommandLineFallback is used and a warning is logged

.PARAMETER UninstallCommandLineFallback
Used when the deployment type has no uninstall command. Intune requires one. The default fails on
purpose (exit code 1) so an uninstall is visible as a failure instead of re-running the installer

.PARAMETER DetectionRules
Detection rules (ruleType detection) produced by ConvertTo-IntuneDetectionRule, New-IntuneScriptDetectionRule
or New-IntuneProductCodeDetectionRule. At least one is required

.PARAMETER MinimumOSArchitecture
The applicable architectures

.PARAMETER MinimumOSVersion
The minimum supported Windows release, in the Graph format Windows<version>_<release>

.PARAMETER InstallExperience
system or user

.PARAMETER RestartBehavior
The device restart behavior

.PARAMETER MaxExecutionTime
The maximum run time in minutes

.PARAMETER AllowAvailableUninstall
Allow uninstall from the Company Portal when the app has an Available assignment

.PARAMETER ReturnCodes
Return code objects with returnCode and type. When not passed, the Intune defaults are used
#>
function New-IntuneWinFramework {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, HelpMessage = "The unique app name as it appears in the company portal")]
        [string]$Name,
        [Parameter(Mandatory = $true, HelpMessage = "The app description for the company portal")]
        [string]$Description,
        [Parameter(Mandatory = $true, HelpMessage = "The publisher name of the app")]
        [string]$Publisher,
        [Parameter(Mandatory = $false, HelpMessage = "The app version of the app")]
        [string]$AppVersion,
        [Parameter(Mandatory = $false, HelpMessage = "The information URL of the app")]
        [string]$InformationURL,
        [Parameter(Mandatory = $false, HelpMessage = "The privacy URL of the app")]
        [string]$PrivacyURL,
        [Parameter(Mandatory = $false, HelpMessage = "The notes associated with the app")]
        [string]$Notes,
        [Parameter(Mandatory = $false, HelpMessage = "The base64 value of the icon of the app")]
        [string]$LargeIcon,
        [Parameter(Mandatory = $true, HelpMessage = "Folder to write Win32appBody.json to")]
        [string]$Path,
        [Parameter(Mandatory = $true, HelpMessage = "The win32app filename value")]
        [string]$FileName,
        [Parameter(Mandatory = $true, HelpMessage = "The name of the setupfile")]
        [string]$SetupFile,
        [Parameter(Mandatory = $true, HelpMessage = "The install command line for the app")]
        [string]$InstallCommandLine,
        [Parameter(Mandatory = $false, HelpMessage = "The uninstall command line for the app")]
        [AllowEmptyString()]
        [string]$UninstallCommandLine,
        [Parameter(Mandatory = $false, HelpMessage = "Uninstall command used when the deployment type has none")]
        [string]$UninstallCommandLineFallback = 'cmd.exe /c exit 1',
        [Parameter(Mandatory = $true, HelpMessage = "Detection rules for the app")]
        [AllowEmptyCollection()]
        [object[]]$DetectionRules,
        [Parameter(Mandatory = $false, HelpMessage = "The applicable architectures")]
        [string]$MinimumOSArchitecture = 'x64,x86',
        [Parameter(Mandatory = $false, HelpMessage = "The minimum supported Windows release")]
        [string]$MinimumOSVersion = 'Windows10_21H2',
        [Parameter(Mandatory = $false, HelpMessage = "system or user")]
        [ValidateSet('system', 'user')]
        [string]$InstallExperience = 'system',
        [Parameter(Mandatory = $false, HelpMessage = "The default restart behavior for the app")]
        [ValidateSet('allow', 'basedOnReturnCode', 'suppress', 'force')]
        [string]$RestartBehavior = 'basedOnReturnCode',
        [Parameter(Mandatory = $false, HelpMessage = "The maximum time (in minutes) that the app is expected to take to execute")]
        [int]$MaxExecutionTime = 60,
        [Parameter(Mandatory = $false, HelpMessage = "Allow uninstall from the Company Portal")]
        [bool]$AllowAvailableUninstall = $false,
        [Parameter(Mandatory = $false, HelpMessage = "Return code objects with returnCode and type")]
        [object[]]$ReturnCodes
    )

    Write-LogAndHost -Message ("Building the Win32 app JSON body for '{0}'" -f $Name) -LogId $LogId -ForegroundColor Cyan

    $rules = @($DetectionRules | Where-Object { $null -ne $_ })
    if ($rules.Count -eq 0) {
        throw ("No detection rules for '{0}'. Intune requires at least one detection rule, so the app was not created" -f $Name)
    }

    if ([string]::IsNullOrWhiteSpace($UninstallCommandLine)) {
        Write-LogAndHost -Message ("The deployment type has no uninstall command. Using '{0}' because Intune requires one; set a real uninstall command in Intune" -f $UninstallCommandLineFallback) -LogId $LogId -Severity 2
        $UninstallCommandLine = $UninstallCommandLineFallback
    }

    if (-not $ReturnCodes -or @($ReturnCodes).Count -eq 0) {
        $ReturnCodes = @(
            [pscustomobject]@{ returnCode = 0; type = 'success' },
            [pscustomobject]@{ returnCode = 1707; type = 'success' },
            [pscustomobject]@{ returnCode = 3010; type = 'softReboot' },
            [pscustomobject]@{ returnCode = 1641; type = 'hardReboot' },
            [pscustomobject]@{ returnCode = 1618; type = 'retry' }
        )
    }

    $returnCodesBody = @(foreach ($code in $ReturnCodes) {
            [ordered]@{
                '@odata.type' = '#microsoft.graph.win32LobAppReturnCode'
                returnCode    = [int]$code.returnCode
                type          = [string]$code.type
            }
        })

    if ($MaxExecutionTime -le 0) { $MaxExecutionTime = 60 }

    $body = [ordered]@{
        '@odata.type'                  = '#microsoft.graph.win32LobApp'
        displayName                    = $Name
        description                    = $Description
        publisher                      = $Publisher
        displayVersion                 = $AppVersion
        informationUrl                 = if ($InformationURL) { $InformationURL } else { $null }
        privacyInformationUrl          = if ($PrivacyURL) { $PrivacyURL } else { $null }
        notes                          = $Notes
        fileName                       = $FileName
        setupFilePath                  = $SetupFile
        installCommandLine             = $InstallCommandLine
        uninstallCommandLine           = $UninstallCommandLine
        minimumSupportedWindowsRelease = $MinimumOSVersion
        applicableArchitectures        = $MinimumOSArchitecture
        allowAvailableUninstall        = $AllowAvailableUninstall
        installExperience              = [ordered]@{
            '@odata.type'         = '#microsoft.graph.win32LobAppInstallExperience'
            runAsAccount          = $InstallExperience
            deviceRestartBehavior = $RestartBehavior
            maxRunTimeInMinutes   = $MaxExecutionTime
        }
        returnCodes                    = $returnCodesBody
        rules                          = $rules
    }

    if ($LargeIcon) {
        $body['largeIcon'] = [ordered]@{
            '@odata.type' = '#microsoft.graph.mimeContent'
            type          = 'image/png'
            value         = $LargeIcon
        }
    }

    $json = $body | ConvertTo-Json -Depth 10 -Compress

    # Log a copy without the icon and script content, which are large
    $logCopy = $json | ConvertFrom-Json
    if ($logCopy.PSObject.Properties['largeIcon']) { $logCopy.largeIcon = 'omitted' }
    foreach ($rule in @($logCopy.rules)) {
        if ($rule.PSObject.Properties['scriptContent']) { $rule.scriptContent = 'omitted' }
    }
    Write-Log -Message ("Win32 app JSON body: {0}" -f ($logCopy | ConvertTo-Json -Depth 10 -Compress)) -LogId $LogId

    $jsonFile = Join-Path -Path $Path -ChildPath 'Win32appBody.json'
    try {
        [System.IO.File]::WriteAllText($jsonFile, $json, (New-Object System.Text.UTF8Encoding $false))
        Write-LogAndHost -Message ("Wrote the JSON body to '{0}'" -f $jsonFile) -LogId $LogId -ForegroundColor Green
    }
    catch {
        Write-LogAndHost -Message ("Could not write the JSON body to '{0}': {1}" -f $jsonFile, $_.Exception.Message) -LogId $LogId -Severity 2
    }

    return $json
}
