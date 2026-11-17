<#
.Synopsis
Created on:   17/02/2024
Update on:    16/11/2026
Created by:   Ben Whitmore
Filename:     Get-LocalDetectionMethods.ps1

.Description
Parses a ConfigMgr enhanced detection method (the 'MethodBody' XML of a deployment type whose
DetectAction provider is 'Local') into a flat list of clauses plus the logical connectors used.

The function ALWAYS returns a single object (never an unrolled array) so callers can safely use
.Count on its collections in Windows PowerShell 5.1, where a lone [pscustomobject] has no .Count
(about_PSCustomObject, Windows PowerShell 5.1 notes). That quirk is why single-rule detections
failed on 5.1 but worked on 7 (issues #24 and #27).

Structure handled (see Tests\Fixtures\DetectionMethods\README.md for the evidence behind each):
  EnhancedDetectionMethod
    Settings            -> File | Folder | SimpleSetting (registry value) | RegistryKey | MSI, keyed by LogicalName
    Rule/Expression     -> either a leaf (Operator + Operands/SettingReference + ConstantValue[List])
                           or a group (Operator And|Or + Operands/Expression...), nested to any depth

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function.

.PARAMETER XMLObject
The enhanced detection method XML, as a string or [xml] document
#>

function Get-DetectionMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The local detection methods XML content')]
        [object]$XMLObject
    )

    if ($XMLObject -is [xml]) {
        $xmlDocument = $XMLObject
    }
    else {
        $xmlDocument = [xml][string]$XMLObject
    }

    $root = $xmlDocument.DocumentElement
    if ($null -eq $root -or $root.LocalName -ne 'EnhancedDetectionMethod') {
        throw "The detection XML is not an EnhancedDetectionMethod document"
    }

    # Index the settings by LogicalName so each rule clause can be joined to its setting
    $settingsIndex = @{}
    $settingsNode = $root.ChildNodes | Where-Object { $_.NodeType -eq 'Element' -and $_.LocalName -eq 'Settings' } | Select-Object -First 1
    if ($settingsNode) {
        foreach ($settingNode in $settingsNode.ChildNodes) {
            if ($settingNode.NodeType -ne 'Element') { continue }
            $logicalName = $settingNode.GetAttribute('LogicalName')
            if ($logicalName) { $settingsIndex[$logicalName] = $settingNode }
        }
    }

    $clauses = New-Object System.Collections.Generic.List[object]
    $connectors = New-Object System.Collections.Generic.List[string]

    # Helper: first child element with a given local name (namespace agnostic)
    function Get-ChildElement {
        param ([System.Xml.XmlNode]$Node, [string]$Name)
        if ($null -eq $Node) { return $null }
        foreach ($child in $Node.ChildNodes) {
            if ($child.NodeType -eq 'Element' -and $child.LocalName -eq $Name) { return $child }
        }
        return $null
    }

    function Get-ChildElements {
        param ([System.Xml.XmlNode]$Node, [string]$Name)
        $found = New-Object System.Collections.Generic.List[System.Xml.XmlNode]
        if ($null -ne $Node) {
            foreach ($child in $Node.ChildNodes) {
                if ($child.NodeType -eq 'Element' -and $child.LocalName -eq $Name) { $found.Add($child) }
            }
        }
        return , $found
    }

    function Get-ElementText {
        param ([System.Xml.XmlNode]$Node, [string]$Name)
        $element = Get-ChildElement -Node $Node -Name $Name
        if ($element) { return $element.InnerText }
        return $null
    }

    function Resolve-Expression {
        param ([System.Xml.XmlNode]$Expression, [int]$Depth)

        $operator = Get-ElementText -Node $Expression -Name 'Operator'
        $operands = Get-ChildElement -Node $Expression -Name 'Operands'
        $childExpressions = Get-ChildElements -Node $operands -Name 'Expression'

        if ($operator -in @('And', 'Or') -and $childExpressions.Count -gt 0) {
            $connectors.Add($operator)
            foreach ($childExpression in $childExpressions) {
                Resolve-Expression -Expression $childExpression -Depth ($Depth + 1)
            }
            return
        }

        $settingReference = Get-ChildElement -Node $operands -Name 'SettingReference'
        $constantValue = Get-ChildElement -Node $operands -Name 'ConstantValue'
        $constantValueList = Get-ChildElement -Node $operands -Name 'ConstantValueList'

        $settingLogicalName = if ($settingReference) { $settingReference.GetAttribute('SettingLogicalName') } else { $null }
        $setting = if ($settingLogicalName -and $settingsIndex.ContainsKey($settingLogicalName)) { $settingsIndex[$settingLogicalName] } else { $null }

        $clause = [ordered]@{
            Depth              = $Depth
            Operator           = $operator
            SettingLogicalName = $settingLogicalName
            SettingSourceType  = if ($settingReference) { $settingReference.GetAttribute('SettingSourceType') } else { $null }
            Method             = if ($settingReference) { $settingReference.GetAttribute('Method') } else { $null }
            PropertyPath       = if ($settingReference -and $settingReference.HasAttribute('PropertyPath')) { $settingReference.GetAttribute('PropertyPath') } else { $null }
            DataType           = if ($settingReference) { $settingReference.GetAttribute('DataType') } else { $null }
            ConstantValue      = if ($constantValue) { $constantValue.GetAttribute('Value') } else { $null }
            ConstantDataType   = if ($constantValue) { $constantValue.GetAttribute('DataType') } else { $null }
            ConstantValueList  = @()
            SettingType        = if ($setting) { $setting.LocalName } else { $null }
            Is64Bit            = $null
            Path               = $null
            Filter             = $null
            Hive               = $null
            Key                = $null
            ValueName          = $null
            ProductCode        = $null
        }

        if ($constantValueList) {
            $clause.ConstantValueList = @( (Get-ChildElements -Node $constantValueList -Name 'ConstantValue') | ForEach-Object { $_.GetAttribute('Value') } )
        }

        if ($setting) {
            switch ($setting.LocalName) {
                { $_ -in @('File', 'Folder') } {
                    $clause.Is64Bit = $setting.GetAttribute('Is64Bit')
                    $clause.Path = Get-ElementText -Node $setting -Name 'Path'
                    $clause.Filter = Get-ElementText -Node $setting -Name 'Filter'
                }
                'SimpleSetting' {
                    $source = Get-ChildElement -Node $setting -Name 'RegistryDiscoverySource'
                    if ($source) {
                        $clause.Is64Bit = $source.GetAttribute('Is64Bit')
                        $clause.Hive = $source.GetAttribute('Hive')
                        $clause.Key = Get-ElementText -Node $source -Name 'Key'
                        $clause.ValueName = Get-ElementText -Node $source -Name 'ValueName'
                    }
                }
                'RegistryKey' {
                    $clause.Is64Bit = $setting.GetAttribute('Is64Bit')
                    $clause.Hive = $setting.GetAttribute('Hive')
                    $clause.Key = Get-ElementText -Node $setting -Name 'Key'
                }
                'MSI' {
                    $clause.ProductCode = Get-ElementText -Node $setting -Name 'ProductCode'
                }
            }
        }

        $clauses.Add([pscustomobject]$clause)
    }

    $ruleNode = $root.ChildNodes | Where-Object { $_.NodeType -eq 'Element' -and $_.LocalName -eq 'Rule' } | Select-Object -First 1
    $rootExpression = Get-ChildElement -Node $ruleNode -Name 'Expression'

    if ($rootExpression) {
        Resolve-Expression -Expression $rootExpression -Depth 0
    }
    else {
        Write-LogAndHost -Message 'The enhanced detection method XML does not contain a Rule/Expression node' -LogId $LogId -Severity 2
    }

    return [pscustomobject]@{
        Clauses    = $clauses.ToArray()
        Connectors = $connectors.ToArray()
        HasOr      = ($connectors -contains 'Or')
    }
}
