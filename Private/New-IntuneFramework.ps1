<#
.Synopsis
Created on:   24/03/2024
Updated on:   01/01/2025
Created by:   Ben Whitmore
Filename:     New-Win32appFramework.ps1

.Description
Function to create a Win32 app JSON framework
Parameter descriptions reference https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-add

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER Name
Enter the name of the app as it appears in the company portal. Make sure all app names 
that you use are unique. If the same app name exists twice, only one of the apps appears 
in the company portal

.PARAMETER Description
Enter the description of the app. The description appears in the company portal

.PARAMETER Publisher
Enter the name of the publisher of the app

.PARAMETER AppVersion
The version of the app

.PARAMETER InformationURL
The URL of a website that contains information about this app. The URL 
appears in the company portal

.PARAMETER PrivacyURL
The URL of a website that contains privacy information for this app. 

.PARAMETER Notes
Enter any notes that you want to associate with this app

.PARAMETER LargeIcon
The base64 value of the icon of the app

.PARAMETER Path
Path to the Win32apps folder

.PARAMETER FileName
The name of the Win32app filename value

.PARAMETER SetupFile
The name of the setup file

.PARAMETER InstallCommandLine
The install command line for the app

.PARAMETER UninstallCommandLine
The uninstall command line for the app

.PARAMETER DetectionMethodJson
The JSON body for the detection method of the app

.PARAMETER DetectionScript
The base64 value of the detection method script for the app

.PARAMETER MinimumOSArchitecture
The minimum operating system architecture required for the app

.PARAMETER MinimumOSVersion
The minimum operating system version required for the app

.PARAMETER InstallExperience
System or User

.PARAMETER RestartBehavior
The default restart behavior for the app

.PARAMETER MaxExecutionTime
The maximum time (in minutes) that the app is expected to take to execute

.PARAMETER AllowAvailableUninstall
When creating the Win32App, allow the user to uninstall the app if it is available in the Company Portal

.PARAMETER ReturnCodeMap
Hash table of default return codes

#>
function New-IntuneWinFramework {
    param(
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = "The unique app name as it appears in the company portal")]
        [string]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = "The app description for the company portal")]
        [string]$Description,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = "The publisher name of the app")]
        [string]$Publisher,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 3, HelpMessage = "The app version of the app")]
        [string]$AppVersion,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 4, HelpMessage = "The information URL of the app")]
        [string]$InformationURL,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 5, HelpMessage = "The privacy URL of the app")]
        [string]$PrivacyURL,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 6, HelpMessage = "The notes associated with the app")]
        [string]$Notes,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 7, HelpMessage = "The base64 value of the icon of the app")]
        [string]$LargeIcon,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 8, HelpMessage = "Path to the Win32apps folder")]
        [string]$Path,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 9, HelpMessage = "The win32app filename value")]
        [string]$FileName,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 10, HelpMessage = "The name of the setupfile")]
        [string]$SetupFile,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 11, HelpMessage = "The install command line for the app")]
        [string]$InstallCommandLine,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 12, HelpMessage = "The uninstall command line for the app")]
        [string]$UninstallCommandLine,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 13, HelpMessage = "The JSON body for the detection method of the app")]
        [string]$DetectionMethodJson,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 14, HelpMessage = "The base64 value of the detection method script for the app")]
        [string]$DetectionScript,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 15, HelpMessage = "The minimum operating system architecture required for the app")]
        [string]$MinimumOSArchitecture = 'x64,x86',
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 16, HelpMessage = "The minimum operating system version required for the app")]
        [string]$MinimumOSVersion = "Windows10_21H2",
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 17, HelpMessage = "System or User")]
        [ValidateSet('System', 'User')]
        [string]$InstallExperience,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 18, HelpMessage = "The mdefault restart behavior for the app")]
        [ValidateSet("allow", "basedOnReturnCode", "suppress", "force")]
        [string]$RestartBehavior = "basedOnReturnCode",
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 19, HelpMessage = "The maximum time (in minutes) that the app is expected to take to execute")]
        [int]$MaxExecutionTime = 60,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, Position = 20, HelpMessage = "When creating the Win32App, allow the user to uninstall the app if it is available in the Company Portal")]
        [bool]$AllowAvailableUninstall,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, Position = 21, HelpMessage = "Hash table of default return codes")]
        [string]$ReturnCodes = '{"0": "success","1707": "success","3010": "softReboot","1641": "hardReboot","1618": "retry"}'
    )

    begin {

        Write-LogAndHost -Message "Function: New-Win32appFramework was called" -LogId $LogId -ForegroundColor Cyan
        Write-LogAndHost -Message ("Processing JSON body for '{0}'" -f $Name) -LogId $LogId -ForegroundColor Cyan

        # Convert the JSON to an array of objects
        [object]$parsedJson = $ReturnCodes | ConvertFrom-Json
        [object]$returnCodesOrdered = foreach ($property in $parsedJson.PSObject.Properties) {
            [PSCustomObject]@{
                returnCode = [int]$property.Name
                type       = [string]$property.Value
            }
        }
    }

    process {
            
        # Create the JSON body for the Win32 app
        $body = [ordered]@{
            '@odata.type'                  = "#microsoft.graph.win32LobApp"
            displayName                    = $Name
            description                    = $Description
            publisher                      = $Publisher
            displayVersion                 = $AppVersion
            informationUrl                 = $InformationURL
            privacyInformationUrl          = $PrivacyURL
            notes                          = $Notes
            installExperience              = [ordered]@{
                '@odata.type'           = "#microsoft.graph.win32LobAppInstallExperience"
                "runAsAccount"          = $InstallExperience
                "deviceRestartBehavior" = $RestartBehavior
                "maxRunTimeInMinutes"   = $MaxExecutionTime
            }
            largeIcon                      = [ordered]@{
                '@odata.type' = "#microsoft.graph.mimeContent"
                type          = "image/png"
                value         = $LargeIcon
            }
            fileName                       = $FileName
            setupFilePath                  = $SetupFile
            installCommandLine             = $deploymentType.InstallCommandLine
            uninstallCommandLine           = $deploymentType.UninstallCommandLine
            minimumSupportedWindowsRelease = $MinimumOSVersion
            applicableArchitectures        = $MinimumOSArchitecture
        }

        # Allow available uninstall
        if ($AllowAvailableUninstall) {
            $body['allowAvailableUninstall'] = $true
        }

        # Add returns codes
        $body['returnCodes'] = $returnCodesOrdered

        # Detection method (rules) for the Win32 app
        $transformedRules = @()

        if ($PSBoundParameters.ContainsKey('DetectionMethodJson')) {
            Write-LogAndHost -Message "Using JSON method for building detection" -LogId $LogId -ForegroundColor Cyan
            $jsonObject = $DetectionMethodJson | ConvertFrom-Json

            # Transform the detection rules from the JSON object
            foreach ($rule in $jsonObject) {

                # File system detection
                if ($rule.'@odata.type' -eq "#microsoft.graph.win32LobAppFileSystemDetection") {
                    $transformedRules += [ordered]@{
                        '@odata.type'        = "microsoft.graph.win32LobAppFileSystemRule"
                        ruleType             = 'detection'
                        check32BitOn64System = $rule.check32BitOn64System
                        operationType        = $rule.detectionType
                        comparisonValue      = $rule.detectionVale
                        fileOrFolderName     = $rule.fileOrFolderName
                        operator             = $rule.operator
                        path                 = $rule.path
                    }
                }
                # Registry detection
                elseif ($rule.'@odata.type' -eq "#microsoft.graph.win32LobAppRegistryDetection") {
                    $transformedRules += [ordered]@{
                        '@odata.type'        = "microsoft.graph.win32LobAppRegistryRule"
                        ruleType             = 'detection'
                        check32BitOn64System = $rule.check32BitOn64System
                        operationType        = $rule.detectionType
                        comparisonValue      = $rule.detectionValue
                        keyPath              = $rule.keyPath
                        operator             = $rule.operator
                        valueName            = $rule.valueName
                    }
                }
                # Product code detection
                elseif ($rule.'@odata.type' -eq "#microsoft.graph.win32LobAppProductCodeRule") {
                    Write-LogAndHost -Message "Using Product code detection" -LogId $LogId -ForegroundColor Cyan
                    $transformedRules += [ordered]@{
                        '@odata.type'          = "#microsoft.graph.win32LobAppProductCodeRule"
                        productCode            = $rule.productCode
                        productVersion         = $rule.productVersion
                        productVersionOperator = $rule.productVersionOperator
                    }
                }
            }
        }
        elseif ($PSBoundParameters.ContainsKey('DetectionScript')) {
            Write-LogAndHost -Message "Using script method for building detection" -LogId $LogId -ForegroundColor Cyan
            $transformedRules += [ordered]@{
                '@odata.type'           = "#microsoft.graph.win32LobAppPowerShellScriptRule"
                'scriptContent'         = $DetectionScript
                'enforceSignatureCheck' = $false
                'runAs32Bit'            = $false
            }
        }

        $body['rules'] = $transformedRules

        # Install experience
        $body['installExperience'] = @{
            "@odata.type" = "microsoft.graph.win32LobAppInstallExperience"
            runAsAccount  = $InstallExperience
        }

        # Create JSON body
        $json = $body | ConvertTo-Json -Depth 5 -Compress

        # Write-Host JSON body but exclude largeIcon and ScriptContent values
        $jsonObject = $body

        if ($jsonObject.Contains("largeIcon")) {
            $jsonObject["largeIcon"] = "Base64IcondDataPresentButOmittedFromOutputDuetoSize"
        }
        if ($jsonObject.Contains("rules") -and $jsonObject["rules"][0].Contains("scriptContent")) {
            $jsonObject["rules"][0]["scriptContent"] = "Base64ScriptDataPresentButOmittedFromOutputDuetoSize"
        }

        Write-LogAndHost -Message "JSON body created" -LogId $LogId -ForegroundColor Cyan
        $jsonOutput = $jsonObject | ConvertTo-Json -Depth 5 -Compress
        Write-LogAndHost -Message ("'{0}'" -f $jsonOutput) -LogId $LogId -ForegroundColor Green
            
        # Write the JSON body to a file
        $jsonFile = Join-Path -Path $Path -ChildPath "Win32appBody.json"
        Write-LogAndHost -Message ("Writing JSON body to '{0}'" -f $jsonFile) -LogId $LogId -ForegroundColor Cyan -NewLine

        try {

            # Write the JSON body to the file
            [System.IO.File]::WriteAllText($jsonFile, $json, [System.Text.Encoding]::UTF8)
            Write-LogAndHost -Message ("Successfully wrote JSON body to '{0}'" -f $jsonFile) -LogId $LogId -ForegroundColor Green

            return $json
        }
        catch {
            Write-LogAndHost -Message ("Failed to write JSON body to '{0}'" -f $jsonFile) -LogId $LogId -Severity 3

            return $false
        }
    }
}