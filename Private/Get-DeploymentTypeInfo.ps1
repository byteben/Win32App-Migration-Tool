<#
.Synopsis
Created on:   28/10/2023
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Get-DeploymentTypeInfo.ps1

.Description
Gets deployment type information from ConfigMgr and converts each deployment type's detection method
into Intune detection rules.

ConvertFrom-SdmPackageXml does the parsing and has no ConfigMgr dependency, so it can be tested against
SDMPackageXML fixtures. Get-DeploymentTypeInfo calls Get-CMApplication, then ConvertFrom-SdmPackageXml,
then writes the detection method files to the working folder for reference.

SDMPackageXML paths used (see Tests\Fixtures\README.md for the evidence):
  DeploymentType/Installer/Contents/Content/Location                       content location(s)
  DeploymentType/Installer/InstallAction/Args/Arg[@Name='ExecutionContext'] System | User | Any
  DeploymentType/Installer/InstallAction/Args/Arg[@Name='PostInstallBehavior'] BasedOnExitCode | NoAction | ProgramReboot | ForceReboot
  DeploymentType/Installer/DetectAction/Provider                            Script | Local | MSI
  DeploymentType/Installer/DetectAction/Args/Arg                            provider specific (ScriptBody, MethodBody, ProductCode...)
  DeploymentType/Installer/CustomData/ExitCodes/ExitCode/@Code, @Class      return codes

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function.

.PARAMETER ApplicationId
The CI_ID of the application to get deployment type information for
#>

function Get-SdmArgValue {
    param (
        [object]$Action,
        [string]$Name
    )

    if ($null -eq $Action -or $null -eq $Action.Args) { return $null }
    foreach ($argument in @($Action.Args.Arg)) {
        if ($null -ne $argument -and $argument.Name -eq $Name) {
            return $argument.InnerText
        }
    }
    return $null
}

function Get-SdmText {
    param ([object]$Node)

    if ($null -eq $Node) { return $null }
    if ($Node -is [string]) { return $Node }
    if ($Node -is [System.Xml.XmlNode]) { return $Node.InnerText }
    return [string]$Node
}

function ConvertTo-IntuneRunAsAccount {
    param ([string]$Context)

    switch ($Context) {
        'System' { return 'system' }
        'User' { return 'user' }
        default { return 'system' }
    }
}

function ConvertTo-IntuneRestartBehavior {
    param ([string]$PostInstallBehavior)

    # ConfigMgr PostInstallBehavior -> Intune deviceRestartBehavior
    switch ($PostInstallBehavior) {
        'BasedOnExitCode' { return 'basedOnReturnCode' }
        'NoAction' { return 'suppress' }
        'ProgramReboot' { return 'allow' }
        'ForceReboot' { return 'force' }
        default { return 'basedOnReturnCode' }
    }
}

function ConvertTo-IntuneReturnCodes {
    param ([object]$ExitCodesNode)

    # Intune defaults, overridden by whatever the deployment type defines
    $codes = [ordered]@{
        '0'    = 'success'
        '1707' = 'success'
        '3010' = 'softReboot'
        '1641' = 'hardReboot'
        '1618' = 'retry'
    }

    $classMap = @{
        'Success'    = 'success'
        'Failure'    = 'failed'
        'SoftReboot' = 'softReboot'
        'HardReboot' = 'hardReboot'
        'FastRetry'  = 'retry'
    }

    if ($null -ne $ExitCodesNode) {
        foreach ($exitCode in @($ExitCodesNode.ExitCode)) {
            if ($null -eq $exitCode) { continue }
            $code = [string]$exitCode.Code
            $class = [string]$exitCode.Class
            $value = 0
            if ([int]::TryParse($code, [ref]$value) -and $classMap.ContainsKey($class)) {
                $codes[$code] = $classMap[$class]
            }
        }
    }

    $result = foreach ($key in $codes.Keys) {
        [pscustomobject]@{ returnCode = [int]$key; type = $codes[$key] }
    }
    return , @($result)
}

function Get-DecodedDetectionScript {
    param ([string]$ScriptBody)

    # Signed scripts are stored base64 encoded between ConfigMgr markers
    $pattern = '# ENCODEDSCRIPT # Begin Configuration Manager encoded script block #\s*(.*?)\s*# ENCODEDSCRIPT# End Configuration Manager encoded script block'
    $match = [regex]::Match([string]$ScriptBody, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

    if ($match.Success) {
        $scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($match.Groups[1].Value))

        # Remove the padding line the XML adds after the encoded block so signatures stay valid
        $lines = $scriptContent -split "`n"
        if ($lines.Count -gt 1) { $lines = $lines[0..($lines.Count - 2)] }
        return ($lines -join "`n")
    }

    return $ScriptBody
}

function Get-SdmRequirement {
    # Describes each requirement rule on a deployment type, for the log and results file. Requirements are not
    # converted to Intune yet: Intune can only express some of them, and the conversion will be built from real
    # exports. The description uses the rule's display name when ConfigMgr stored one, otherwise its operator,
    # setting and values. Namespace-agnostic, and never throws
    param ([System.Xml.XmlNode]$DeploymentTypeNode)

    $descriptions = New-Object System.Collections.Generic.List[string]
    if ($null -eq $DeploymentTypeNode) { return , $descriptions.ToArray() }

    try {
        $rules = $DeploymentTypeNode.SelectNodes("./*[local-name()='Requirements']/*[local-name()='Rule']")
        foreach ($rule in $rules) {
            $displayName = $rule.SelectSingleNode("./*[local-name()='Annotation']/*[local-name()='DisplayName']")
            $text = $null
            if ($null -ne $displayName) { $text = $displayName.GetAttribute('Text') }

            if ([string]::IsNullOrWhiteSpace($text)) {
                $operator = $rule.SelectSingleNode(".//*[local-name()='Operator']")
                $settings = @($rule.SelectNodes(".//*[local-name()='GlobalSettingReference' or local-name()='SettingReference']") | ForEach-Object {
                        $name = (@($_.GetAttribute('LogicalName'), $_.GetAttribute('SettingLogicalName')) | Where-Object { $_ } | Select-Object -Unique) -join '/'
                        if ($name) { $name }
                    })
                $values = @($rule.SelectNodes(".//*[local-name()='ConstantValue']") | ForEach-Object { $_.GetAttribute('Value') } | Where-Object { $_ })
                $parts = @()
                if ($settings.Count -gt 0) { $parts += ($settings | Select-Object -Unique) -join ', ' }
                if ($null -ne $operator) { $parts += $operator.InnerText }
                if ($values.Count -gt 0) { $parts += ($values -join ', ') }
                $text = $parts -join ' '
            }

            if ([string]::IsNullOrWhiteSpace($text)) { $text = "Rule '$($rule.GetAttribute('id'))'" }
            $descriptions.Add($text.Trim())
        }
    }
    catch {
        $descriptions.Add("The requirements couldn't be read: $($_.Exception.Message)")
    }

    return , $descriptions.ToArray()
}

function Get-SdmLeftoverDetection {
    # Reports detection data that doesn't belong to the active provider. It never changes which detection is used
    param (
        [object]$DetectAction,
        [object]$CustomData,
        [string]$Provider
    )

    $messages = New-Object System.Collections.Generic.List[string]
    $argsByProvider = @{
        'Script' = @('ExecutionContext', 'ScriptType', 'ScriptBody', 'RunAs32Bit')
        'Local'  = @('ExecutionContext', 'MethodBody')
        'MSI'    = @('ExecutionContext', 'ProductCode', 'PackageCode', 'PatchCodes')
    }
    # Values seen in real exports. An MSI deployment type (lab app R1) says 'ProductCode'
    $customDataByProvider = @{ 'Script' = 'Script'; 'Local' = 'Enhanced'; 'MSI' = 'ProductCode' }

    if (-not $argsByProvider.ContainsKey([string]$Provider)) { return , $messages.ToArray() }

    if ($null -ne $DetectAction -and $null -ne $DetectAction.Args) {
        $extra = @(@($DetectAction.Args.Arg) | Where-Object { $null -ne $_ -and $_.Name -notin $argsByProvider[$Provider] -and -not [string]::IsNullOrWhiteSpace($_.InnerText) } | ForEach-Object { $_.Name })
        if ($extra.Count -gt 0) {
            $messages.Add(("The detection also contains '{0}' from another detection type, probably left over from an earlier detection method. It was ignored; the active '{1}' detection was used" -f ($extra -join "', '"), $Provider))
        }
    }

    # Seen in real exports (lab apps L30 and L31): when the detection method is changed in the console, ConfigMgr
    # updates DetectAction and CustomData/DetectionMethod but keeps the old detection in CustomData, as a
    # DetectionScript element (script changed to rules) or an EnhancedDetectionMethod element (rules changed to script)
    if ($null -ne $CustomData) {
        $hasOldScript = $null -ne $CustomData.SelectSingleNode("./*[local-name()='DetectionScript']")
        $hasOldRules = $null -ne $CustomData.SelectSingleNode("./*[local-name()='EnhancedDetectionMethod']")
        if ($Provider -ne 'Script' -and $hasOldScript) {
            $messages.Add(("The deployment type still holds an earlier detection script, which ConfigMgr keeps when the detection method is changed. It was ignored; the active '{0}' detection was migrated" -f $Provider))
        }
        if ($Provider -ne 'Local' -and $hasOldRules) {
            $messages.Add(("The deployment type still holds earlier detection rules, which ConfigMgr keeps when the detection method is changed. They were ignored; the active '{0}' detection was migrated" -f $Provider))
        }

        $customDetection = Get-SdmText -Node $CustomData.DetectionMethod
        if ($customDetection -and $customDetection -ne $customDataByProvider[$Provider]) {
            $messages.Add(("CustomData says the detection method is '{0}' but the active detection provider is '{1}'. The active provider was used" -f $customDetection, $Provider))
        }
    }

    return , $messages.ToArray()
}

function ConvertFrom-SdmPackageXml {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'The SDMPackageXML of the application')]
        [string]$SdmPackageXml,
        [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'The CI_ID of the application')]
        [string]$ApplicationId
    )

    $xmlContent = [xml]$SdmPackageXml
    $application = $xmlContent.AppMgmtDigest.Application
    $applicationName = Get-SdmText -Node $application.Title
    $deploymentTypes = New-Object System.Collections.Generic.List[object]

    foreach ($object in @($xmlContent.AppMgmtDigest.DeploymentType)) {
        if ($null -eq $object) { continue }

        # Every value is computed fresh for each deployment type. Earlier versions reused variables
        # from the previous deployment type, so a Local detection could inherit a Script detection
        $installer = $object.Installer
        $warnings = New-Object System.Collections.Generic.List[string]

        # Content locations: first = install, second (if present) = uninstall
        $locations = @($installer.Contents.Content | ForEach-Object { if ($_) { Get-SdmText -Node $_.Location } } | Where-Object { $_ })
        $installLocation = $null
        $uninstallLocation = $null
        if ($locations.Count -gt 0) {
            $installLocation = $locations[0].TrimEnd('\')
            $uninstallLocation = $installLocation
            if ($locations.Count -gt 1) { $uninstallLocation = $locations[1].TrimEnd('\') }
        }
        else {
            $warnings.Add('The deployment type has no content location')
        }

        # Execution context lives in the install action arguments. Fall back to the attribute older versions read
        $dtExecutionContext = Get-SdmArgValue -Action $installer.InstallAction -Name 'ExecutionContext'
        if (-not $dtExecutionContext) { $dtExecutionContext = [string]$installer.ExecutionContext }
        $installExperience = ConvertTo-IntuneRunAsAccount -Context $dtExecutionContext
        if ($dtExecutionContext -notin @('System', 'User')) {
            $warnings.Add(("Execution context '{0}' has no Intune equivalent; using 'system'" -f $dtExecutionContext))
        }

        $postInstallBehavior = Get-SdmArgValue -Action $installer.InstallAction -Name 'PostInstallBehavior'
        $customData = $installer.CustomData

        $detection = [ordered]@{
            Provider         = Get-SdmText -Node $installer.DetectAction.Provider
            ExecutionContext = Get-SdmArgValue -Action $installer.DetectAction -Name 'ExecutionContext'
            ScriptType       = $null
            ScriptRunAs32Bit = $null
            ScriptContent    = $null
            MethodBody       = $null
            ProductCode      = $null
            PackageCode      = $null
            PatchCodes       = $null
            Rules            = @()
            Supported        = $false
            Issues           = @()
        }

        try {
            switch ($detection.Provider) {
                'Script' {
                    $detection.ScriptType = Get-SdmArgValue -Action $installer.DetectAction -Name 'ScriptType'
                    $detection.ScriptRunAs32Bit = Get-SdmArgValue -Action $installer.DetectAction -Name 'RunAs32Bit'
                    $detection.ScriptContent = Get-DecodedDetectionScript -ScriptBody (Get-SdmArgValue -Action $installer.DetectAction -Name 'ScriptBody')
                    $converted = New-IntuneScriptDetectionRule -ScriptContent ([string]$detection.ScriptContent) -ScriptType ([string]$detection.ScriptType) -RunAs32Bit ($detection.ScriptRunAs32Bit -eq 'true')
                }
                'Local' {
                    $detection.MethodBody = Get-SdmArgValue -Action $installer.DetectAction -Name 'MethodBody'
                    $parsed = Get-DetectionMethod -LogId $LogId -XMLObject $detection.MethodBody
                    $converted = ConvertTo-IntuneDetectionRule -LogId $LogId -Detection $parsed
                }
                'MSI' {
                    $detection.ProductCode = Get-SdmArgValue -Action $installer.DetectAction -Name 'ProductCode'
                    $detection.PackageCode = Get-SdmArgValue -Action $installer.DetectAction -Name 'PackageCode'
                    $detection.PatchCodes = Get-SdmArgValue -Action $installer.DetectAction -Name 'PatchCodes'
                    $converted = New-IntuneProductCodeDetectionRule -ProductCode ([string]$detection.ProductCode)
                }
                default {
                    $converted = [pscustomobject]@{ Rules = @(); Unsupported = @("Detection provider '$($detection.Provider)' isn't supported"); IsSupported = $false }
                }
            }
        }
        catch {
            $converted = [pscustomobject]@{ Rules = @(); Unsupported = @("The detection method couldn't be read: $($_.Exception.Message)"); IsSupported = $false }
        }

        $detection.Rules = @($converted.Rules)
        $detection.Issues = @($converted.Unsupported)
        $detection.Supported = [bool]$converted.IsSupported

        # When a deployment type's detection is changed (for example from a script to a file rule), parts of the
        # old detection can stay in the XML. Only DetectAction/Provider and that provider's arguments are used;
        # anything else is reported so it's clear it was ignored
        # Both helpers return their list with 'return ,' so assign first, then enumerate (wrapping the call in @()
        # would give a one-element array holding the list)
        $leftovers = Get-SdmLeftoverDetection -DetectAction $installer.DetectAction -CustomData $customData -Provider $detection.Provider
        foreach ($leftover in $leftovers) {
            $warnings.Add($leftover)
        }

        # Requirements are reported, not migrated, and never stop the migration
        $requirements = Get-SdmRequirement -DeploymentTypeNode $object
        if ($null -eq $requirements) { $requirements = @() }
        if ($requirements.Count -gt 0) {
            $warnings.Add(("Requirements not migrated to Intune: {0}. Recreate them as Intune requirements or assignment filters if they're still needed" -f ($requirements -join '; ')))
        }

        $deploymentTypes.Add([pscustomobject]@{
                Application_Id                = $ApplicationId
                ApplicationName               = $applicationName
                Application_LogicalName       = [string]$application.LogicalName
                LogicalName                   = [string]$object.LogicalName
                Name                          = Get-SdmText -Node $object.Title
                Technology                    = [string]$installer.Technology
                ExecutionContext              = $dtExecutionContext
                InstallExperience             = $installExperience
                InstallContent                = $installLocation
                InstallCommandLine            = Get-SdmText -Node $customData.InstallCommandLine
                UnInstallSetting              = Get-SdmText -Node $customData.UninstallSetting
                UninstallContent              = $uninstallLocation
                UninstallCommandLine          = Get-SdmText -Node $customData.UninstallCommandLine
                ExecuteTime                   = Get-SdmText -Node $customData.ExecuteTime
                MaxExecuteTime                = Get-SdmText -Node $customData.MaxExecuteTime
                PostInstallBehavior           = $postInstallBehavior
                RestartBehavior               = ConvertTo-IntuneRestartBehavior -PostInstallBehavior $postInstallBehavior
                ReturnCodes                   = ConvertTo-IntuneReturnCodes -ExitCodesNode $customData.ExitCodes
                DetectionProvider             = $detection.Provider
                DetectionTypeScriptRunAs32Bit = $detection.ScriptRunAs32Bit
                DetectionTypeScriptType       = $detection.ScriptType
                DetectionTypeExecutionContext = $detection.ExecutionContext
                DetectionTypeProductCode      = $detection.ProductCode
                DetectionTypePackageCode      = $detection.PackageCode
                DetectionTypePatchCodes       = $detection.PatchCodes
                DetectionScriptContent        = $detection.ScriptContent
                DetectionMethodBody           = $detection.MethodBody
                DetectionRules                = $detection.Rules
                DetectionSupported            = $detection.Supported
                DetectionIssues               = ($detection.Issues -join ' | ')
                Requirements                  = ($requirements -join '; ')
                Warnings                      = ($warnings -join ' | ')
                DetectionMethodScriptFile     = $null
                DetectionMethodXmlFile        = $null
                DetectionMethodJsonFile       = $null
            })
    }

    return , $deploymentTypes.ToArray()
}

function Get-DeploymentTypeInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The id of the application to get information for')]
        [string]$ApplicationId
    )

    # Characters that are not allowed in Windows folder names
    $invalidChars = '[<>:"/\\|\?\*]'

    # Get UTF-8 encoding without BOM
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false

    Write-LogAndHost -Message ("Invoking Get-CMApplication where Id equals '{0}'" -f $ApplicationId) -LogId $LogId -ForegroundColor Cyan
    $xmlPackage = Get-CMApplication -Id $ApplicationId | Where-Object { $null -ne $_.SDMPackageXML } | Select-Object -First 1 -ExpandProperty SDMPackageXML

    if (-not $xmlPackage) {
        throw ("Get-CMApplication returned no SDMPackageXML for application Id '{0}'" -f $ApplicationId)
    }

    $deploymentTypes = ConvertFrom-SdmPackageXml -LogId $LogId -SdmPackageXml $xmlPackage -ApplicationId $ApplicationId

    if ($deploymentTypes.Count -eq 0) {
        Write-LogAndHost -Message ("No deployment types found for application Id '{0}'" -f $ApplicationId) -LogId $LogId -Severity 2
        return , @()
    }

    Write-LogAndHost -Message ("The total number of deployment types for '{0}' is '{1}'" -f $deploymentTypes[0].ApplicationName, $deploymentTypes.Count) -LogId $LogId -ForegroundColor Green

    foreach ($deploymentType in $deploymentTypes) {

        # Detection Methods child folder, recreated each run so files from an earlier run can't be picked up
        $applicationNameSanitized = ([string]$deploymentType.ApplicationName -replace $invalidChars, '_').TrimEnd('.', ' ')
        $deploymentTypeNameSanitized = ([string]$deploymentType.Name -replace $invalidChars, '_').TrimEnd('.', ' ')
        $detectionMethodsFolderPath = "{0}\{1}" -f $applicationNameSanitized, $deploymentTypeNameSanitized
        $detectionMethodsFolder = Join-Path -Path "$workingFolder_Root\DetectionMethods" -ChildPath $detectionMethodsFolderPath

        New-FolderToCreate -Root "$workingFolder_Root\DetectionMethods" -FolderNames $detectionMethodsFolderPath

        foreach ($file in [System.IO.Directory]::GetFiles($detectionMethodsFolder)) {
            Write-Log -Message ("Removing existing file '{0}'" -f $file) -LogId $LogId -Severity 2
            [System.IO.File]::Delete($file)
        }

        Write-LogAndHost -Message ("Deployment type '{0}': detection provider is '{1}'" -f $deploymentType.Name, $deploymentType.DetectionProvider) -LogId $LogId -ForegroundColor Cyan

        try {
            switch ($deploymentType.DetectionProvider) {
                'Script' {
                    $extension = switch ($deploymentType.DetectionTypeScriptType) { '1' { '.vbs' } '2' { '.js' } default { '.ps1' } }
                    $deploymentType.DetectionMethodScriptFile = Join-Path -Path $detectionMethodsFolder -ChildPath "DetectionScript$extension"
                    [System.IO.File]::WriteAllText($deploymentType.DetectionMethodScriptFile, [string]$deploymentType.DetectionScriptContent, $utf8NoBomEncoding)
                }
                'Local' {
                    $deploymentType.DetectionMethodXmlFile = Join-Path -Path $detectionMethodsFolder -ChildPath 'MethodBody.xml'
                    [System.IO.File]::WriteAllText($deploymentType.DetectionMethodXmlFile, [string]$deploymentType.DetectionMethodBody, $utf8NoBomEncoding)
                }
            }

            if (@($deploymentType.DetectionRules).Count -gt 0) {
                $deploymentType.DetectionMethodJsonFile = Join-Path -Path $detectionMethodsFolder -ChildPath 'DetectionRules.json'
                $rulesJson = ConvertTo-Json -InputObject @($deploymentType.DetectionRules) -Depth 5
                [System.IO.File]::WriteAllText($deploymentType.DetectionMethodJsonFile, $rulesJson, $utf8NoBomEncoding)
            }
        }
        catch {
            Write-LogAndHost -Message ("Could not write the detection method files to '{0}': {1}" -f $detectionMethodsFolder, $_.Exception.Message) -LogId $LogId -Severity 2
        }

        if ($deploymentType.DetectionSupported) {
            Write-LogAndHost -Message ("Converted the detection method to {0} Intune rule(s)" -f @($deploymentType.DetectionRules).Count) -LogId $LogId -ForegroundColor Green
        }
        else {
            Write-LogAndHost -Message ("The detection method can't be migrated automatically: {0}" -f $deploymentType.DetectionIssues) -LogId $LogId -Severity 2
        }

        if ($deploymentType.Warnings) {
            Write-LogAndHost -Message ("Warnings for '{0}': {1}" -f $deploymentType.Name, $deploymentType.Warnings) -LogId $LogId -Severity 2
        }

        Write-Log -Message ("Deployment type: {0}" -f ($deploymentType | Select-Object -Property * -ExcludeProperty DetectionRules, DetectionScriptContent, DetectionMethodBody, ReturnCodes | ConvertTo-Json -Compress -Depth 3)) -LogId $LogId
    }

    return , $deploymentTypes
}
