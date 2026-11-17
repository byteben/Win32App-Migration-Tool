<#
.Synopsis
Created on:   17/03/2024
Update on:    16/11/2026
Created by:   Ben Whitmore
Filename:     New-IntuneDetection.ps1

.Description
Converts ConfigMgr detection data into Microsoft Graph win32LobApp detection rules (the 'rules'
collection, ruleType = detection).

Graph contract (Microsoft Graph beta, win32LobAppFileSystemRule / win32LobAppRegistryRule /
win32LobAppProductCodeRule / win32LobAppPowerShellScriptRule):
  operator                 notConfigured | equal | notEqual | greaterThan | greaterThanOrEqual | lessThan | lessThanOrEqual
  file operationType       exists | doesNotExist | modifiedDate | createdDate | version | sizeInMB
  registry operationType   exists | doesNotExist | string | integer | version
ConfigMgr operators with no Graph equivalent (Between, OneOf, NoneOf, BeginsWith, EndsWith, Contains...)
and OR logic (Intune ANDs every detection rule) are reported as unsupported rather than guessed.

.PARAMETER Detection
The object returned by Get-DetectionMethod
#>

function Get-IntuneRuleOperator {
    param ([string]$Operator)

    $map = @{
        'Equals'        = 'equal'
        'NotEquals'     = 'notEqual'
        'GreaterThan'   = 'greaterThan'
        'GreaterEquals' = 'greaterThanOrEqual'
        'LessThan'      = 'lessThan'
        'LessEquals'    = 'lessThanOrEqual'
    }

    if ($Operator -and $map.ContainsKey($Operator)) { return $map[$Operator] }
    return $null
}

function ConvertTo-IntuneDateString {
    param ([string]$Value)

    # ConfigMgr stores DateTime constants as ISO 8601 ('2021-06-01T00:00:00Z'). Intune expects
    # milliseconds ('2021-06-01T00:00:00.000Z')
    $parsed = [datetime]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal
    if ([datetime]::TryParse($Value, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) {
        return $parsed.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'", [System.Globalization.CultureInfo]::InvariantCulture)
    }
    return $null
}

function ConvertTo-IntuneDetectionRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'The object returned by Get-DetectionMethod')]
        [object]$Detection
    )

    $rules = New-Object System.Collections.Generic.List[object]
    $unsupported = New-Object System.Collections.Generic.List[string]

    if ($Detection.HasOr) {
        $unsupported.Add("The ConfigMgr detection uses OR logic. Intune evaluates every detection rule with AND, so the rules can't be converted without changing their meaning. Use a detection script for this app.")
    }

    foreach ($clause in @($Detection.Clauses)) {

        $label = "{0} '{1}'" -f $clause.SettingType, $clause.SettingLogicalName

        if (-not $clause.SettingType) {
            $unsupported.Add("Clause references setting '$($clause.SettingLogicalName)' which was not found in the detection XML")
            continue
        }

        if ($clause.ConstantValueList.Count -gt 0) {
            $unsupported.Add("$label uses the '$($clause.Operator)' operator with a list of values, which Intune can't express")
            continue
        }

        $intuneOperator = Get-IntuneRuleOperator -Operator $clause.Operator
        $check32BitOn64System = ([string]$clause.Is64Bit -eq 'false')
        $isBoolean = ($clause.DataType -eq 'Boolean' -or $clause.ConstantDataType -eq 'Boolean')
        $isCountExists = ($clause.Method -eq 'Count' -and $clause.Operator -eq 'NotEquals' -and [string]$clause.ConstantValue -eq '0')

        switch ($clause.SettingType) {

            { $_ -in @('File', 'Folder') } {
                $rule = [ordered]@{
                    '@odata.type'        = '#microsoft.graph.win32LobAppFileSystemRule'
                    ruleType             = 'detection'
                    path                 = $clause.Path
                    fileOrFolderName     = $clause.Filter
                    check32BitOn64System = $check32BitOn64System
                    operationType        = $null
                    operator             = $null
                    comparisonValue      = $null
                }

                if ($clause.Method -eq 'Count') {
                    if ($isCountExists) {
                        $rule.operationType = 'exists'
                        $rule.operator = 'notConfigured'
                        $rules.Add($rule)
                    }
                    else {
                        $unsupported.Add("$label checks the item count with '$($clause.Operator) $($clause.ConstantValue)'. Only 'exists' (NotEquals 0) can be converted")
                    }
                    continue
                }

                if (-not $intuneOperator) {
                    $unsupported.Add("$label uses the '$($clause.Operator)' operator, which has no Intune equivalent")
                    continue
                }

                # Note: 'continue' inside a switch only leaves that switch, so problems are
                # collected in $problem and checked after the switch
                $problem = $null
                switch ($clause.PropertyPath) {
                    'Version' {
                        if ($clause.SettingType -ne 'File') { $problem = "$label compares Version on a folder" }
                        else {
                            $rule.operationType = 'version'
                            $rule.comparisonValue = [string]$clause.ConstantValue
                        }
                    }
                    'Size' {
                        $bytes = [int64]0
                        if ($clause.SettingType -ne 'File') { $problem = "$label compares Size on a folder" }
                        elseif (-not [int64]::TryParse([string]$clause.ConstantValue, [ref]$bytes)) {
                            $problem = "$label has a size value '$($clause.ConstantValue)' that isn't a number of bytes"
                        }
                        elseif ($bytes % 1MB -ne 0) {
                            $problem = "$label compares file size to $bytes bytes. Intune only compares whole MB, so the rule would change meaning"
                        }
                        else {
                            $rule.operationType = 'sizeInMB'
                            $rule.comparisonValue = [string]($bytes / 1MB)
                        }
                    }
                    { $_ -in @('DateModified', 'DateCreated') } {
                        $date = ConvertTo-IntuneDateString -Value $clause.ConstantValue
                        if (-not $date) { $problem = "$label has a date value '$($clause.ConstantValue)' that couldn't be parsed" }
                        else {
                            $rule.operationType = if ($clause.PropertyPath -eq 'DateModified') { 'modifiedDate' } else { 'createdDate' }
                            $rule.comparisonValue = $date
                        }
                    }
                    default {
                        $problem = "$label compares property '$($clause.PropertyPath)', which Intune doesn't support"
                    }
                }

                if ($problem) {
                    $unsupported.Add($problem)
                }
                else {
                    $rule.operator = $intuneOperator
                    $rules.Add($rule)
                }
            }

            { $_ -in @('SimpleSetting', 'RegistryKey') } {
                $keyPath = if ($clause.Hive -and $clause.Key) { '{0}\{1}' -f $clause.Hive, $clause.Key.TrimStart('\') } else { $clause.Key }
                $rule = [ordered]@{
                    '@odata.type'        = '#microsoft.graph.win32LobAppRegistryRule'
                    ruleType             = 'detection'
                    check32BitOn64System = $check32BitOn64System
                    keyPath              = $keyPath
                    valueName            = if ($clause.SettingType -eq 'SimpleSetting' -and $clause.ValueName) { $clause.ValueName } else { $null }
                    operationType        = $null
                    operator             = $null
                    comparisonValue      = $null
                }

                # Existence: ConfigMgr writes a Boolean comparison against true/false
                # ('RegistryValueExists' for a value). A Count <> 0 check is treated the same way.
                if ($isBoolean -or $isCountExists) {
                    $expected = if ($isCountExists) { $true } else { [string]$clause.ConstantValue -eq 'true' }
                    if ($clause.Operator -eq 'NotEquals' -and -not $isCountExists) { $expected = -not $expected }
                    elseif ($clause.Operator -notin @('Equals', 'NotEquals')) {
                        $unsupported.Add("$label checks existence with the '$($clause.Operator)' operator"); continue
                    }
                    $rule.operationType = if ($expected) { 'exists' } else { 'doesNotExist' }
                    $rule.operator = 'notConfigured'
                    $rules.Add($rule)
                    continue
                }

                if ($clause.SettingType -eq 'RegistryKey') {
                    $unsupported.Add("$label is a registry key rule that isn't an existence check"); continue
                }

                if (-not $intuneOperator) {
                    $unsupported.Add("$label uses the '$($clause.Operator)' operator, which has no Intune equivalent")
                    continue
                }

                $registryType = switch ($clause.DataType) {
                    'String' { 'string' }
                    'Int64' { 'integer' }
                    'Integer' { 'integer' }
                    'Version' { 'version' }
                    default { $null }
                }
                if (-not $registryType) {
                    $unsupported.Add("$label compares data type '$($clause.DataType)', which Intune doesn't support"); continue
                }

                $rule.operationType = $registryType
                $rule.operator = $intuneOperator
                $rule.comparisonValue = [string]$clause.ConstantValue
                $rules.Add($rule)
            }

            'MSI' {
                $rule = [ordered]@{
                    '@odata.type'          = '#microsoft.graph.win32LobAppProductCodeRule'
                    ruleType               = 'detection'
                    productCode            = $clause.ProductCode
                    productVersionOperator = 'notConfigured'
                    productVersion         = $null
                }

                if ($isCountExists) {
                    $rules.Add($rule)
                    continue
                }

                if ($clause.DataType -eq 'Version' -and $intuneOperator) {
                    $rule.productVersionOperator = $intuneOperator
                    $rule.productVersion = [string]$clause.ConstantValue
                    $rules.Add($rule)
                    continue
                }

                $unsupported.Add("$label uses '$($clause.Method)/$($clause.DataType)/$($clause.Operator)', which can't be converted to a product code rule")
            }

            default {
                $unsupported.Add("Detection setting type '$($clause.SettingType)' isn't supported")
            }
        }
    }

    return [pscustomobject]@{
        Rules       = $rules.ToArray()
        Unsupported = $unsupported.ToArray()
        IsSupported = ($unsupported.Count -eq 0 -and $rules.Count -gt 0)
    }
}

function New-IntuneScriptDetectionRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'The detection script content')]
        [AllowEmptyString()]
        [string]$ScriptContent,
        [Parameter(Mandatory = $false, HelpMessage = 'ConfigMgr ScriptType: 0 = PowerShell, 1 = VBScript, 2 = JScript')]
        [string]$ScriptType = '0',
        [Parameter(Mandatory = $false, HelpMessage = 'Run the script as a 32-bit process on 64-bit clients')]
        [bool]$RunAs32Bit = $false
    )

    if ($ScriptType -ne '0') {
        $language = switch ($ScriptType) { '1' { 'VBScript' } '2' { 'JScript' } default { "script type '$ScriptType'" } }
        return [pscustomobject]@{
            Rules       = @()
            Unsupported = @("The ConfigMgr detection is a $language script. Intune only runs PowerShell detection scripts, so it must be rewritten in PowerShell")
            IsSupported = $false
        }
    }

    if ([string]::IsNullOrWhiteSpace($ScriptContent)) {
        return [pscustomobject]@{ Rules = @(); Unsupported = @('The detection script is empty'); IsSupported = $false }
    }

    $rule = [ordered]@{
        '@odata.type'         = '#microsoft.graph.win32LobAppPowerShellScriptRule'
        ruleType              = 'detection'
        enforceSignatureCheck = $false
        runAs32Bit            = $RunAs32Bit
        scriptContent         = [System.Convert]::ToBase64String([byte[]]([System.Text.Encoding]::UTF8.GetPreamble() + [System.Text.Encoding]::UTF8.GetBytes($ScriptContent.TrimStart([char]0xFEFF))))
        operationType         = 'notConfigured'
        operator              = 'notConfigured'
    }

    return [pscustomobject]@{ Rules = @($rule); Unsupported = @(); IsSupported = $true }
}

function New-IntuneProductCodeDetectionRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'The MSI product code')]
        [AllowEmptyString()]
        [string]$ProductCode
    )

    if ($ProductCode -notmatch '^\{?[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\}?$') {
        return [pscustomobject]@{ Rules = @(); Unsupported = @("The MSI detection product code '$ProductCode' isn't a valid GUID"); IsSupported = $false }
    }

    $rule = [ordered]@{
        '@odata.type'          = '#microsoft.graph.win32LobAppProductCodeRule'
        ruleType               = 'detection'
        productCode            = $ProductCode
        productVersionOperator = 'notConfigured'
        productVersion         = $null
    }

    return [pscustomobject]@{ Rules = @($rule); Unsupported = @(); IsSupported = $true }
}
