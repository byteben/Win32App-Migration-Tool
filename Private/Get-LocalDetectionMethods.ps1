<#
.Synopsis
Created on:   17/02/2024
Update on:    04/01/2025
Created by:   Ben Whitmore
Filename:     Get-LocalDetectionMethods.ps1

.Description
Function to get the local detection methods from the detection methods xml object

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER XMLObject
The XML content object to extract the detection methods from
#>

function Get-DetectionMethod {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The local detection methods XML content')]
        [object]$XMLObject
    )
    begin {
        # Convert the XMLObject to an XML document
        [xml]$xmlDocument = $XMLObject

        # Create a namespace manager for the XML document
        $namespaceManager = New-Object System.Xml.XmlNamespaceManager($xmlDocument.NameTable)
        $namespaceManager.AddNamespace("def", "http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest")
    }
    process {
        # Create an empty array to store the settings
        $settings = @()

        # Helper function to iterate through the XML nodes and find SettingReferences
        function Find-SettingReferences {
            param (
                [System.Xml.XmlNode]$node,
                [ref]$rules
            )

            # If the node is a SettingReference, add it to the rules
            if ($node.Name -eq 'SettingReference') {
                $logicalName = $node.SettingLogicalName

                if ($logicalName) {

                    if (-not $rules.Value.ContainsKey($logicalName)) {
                        $rules.Value[$logicalName] = @()
                    }

                    $parentExpression = $node.ParentNode.ParentNode
                    $ruleDetail = @{
                        Operator         = $parentExpression.Operator
                        ConstantValue    = $parentExpression.Operands.ConstantValue.Value
                        ConstantDataType = $parentExpression.Operands.ConstantValue.DataType
                    }
                    $rules.Value[$logicalName] += $ruleDetail
                }
            }
            # If the node is an Operands or Expression node, iterate through its child nodes to get SettingReferences
            elseif ($node.Name -eq 'Operands' -or $node.Name -eq 'Expression') {
                foreach ($childNode in $node.ChildNodes) {
                    
                    Find-SettingReferences -Node $childNode -Rules ([ref]$rules.Value)
                }
            }
        }

        # Pre-process rules to match settings
        $rules = @{}

        # Find SettingReferences in the first level of the EnhancedDetectionMethod
        if ($xmlDocument.EnhancedDetectionMethod.Rule.Expression.Operands.Expression) {
            $xmlDocument.EnhancedDetectionMethod.Rule.Expression.Operands.Expression | ForEach-Object {
                Find-SettingReferences -Node $_ -Rules ([ref]$rules)
            }
        }

        # Find SettingReferences if a child operands node doesn't exist
        elseif ($xmlDocument.EnhancedDetectionMethod.Rule.Expression) {
            $xmlDocument.EnhancedDetectionMethod.Rule.Expression | ForEach-Object {
                Find-SettingReferences -Node $_ -Rules ([ref]$rules)
            }
        }
        
        # Create an array to store the settings
        $settingsNodes = $xmlDocument.DocumentElement.SelectNodes("//def:Settings/*", $namespaceManager)
        foreach ($node in $settingsNodes) {
            $logicalName = $node.LogicalName

            $setting = [PSCustomObject]@{
                Type        = $node.LocalName
                LogicalName = $logicalName
            }
            
            # Populate specific properties based on the type of setting
            switch ($node.LocalName) {
                "SimpleSetting" {
                    $setting | Add-Member -NotePropertyName "DataType" -NotePropertyValue $node.DataType
                    $setting | Add-Member -NotePropertyName "Is64Bit" -NotePropertyValue $node.RegistryDiscoverySource.Is64Bit
                    $setting | Add-Member -NotePropertyName "Depth" -NotePropertyValue $node.RegistryDiscoverySource.Depth
                    $setting | Add-Member -NotePropertyName "Hive" -NotePropertyValue $node.RegistryDiscoverySource.Hive
                    $setting | Add-Member -NotePropertyName "Key" -NotePropertyValue $node.RegistryDiscoverySource.Key
                    $setting | Add-Member -NotePropertyName "ValueName" -NotePropertyValue $node.RegistryDiscoverySource.ValueName
                }
                "File" {
                    $setting | Add-Member -NotePropertyName "Is64Bit" -NotePropertyValue $node.Is64Bit
                    $setting | Add-Member -NotePropertyName "Path" -NotePropertyValue $node.Path
                    $setting | Add-Member -NotePropertyName "Filter" -NotePropertyValue $node.Filter
                }
                "MSI" {
                    $setting | Add-Member -NotePropertyName "ProductCode" -NotePropertyValue $node.ProductCode
                }
            }

            # Dynamically add rules as additional properties
            if ($rules.ContainsKey($logicalName)) {
                foreach ($rule in $rules[$logicalName]) {
                    $setting | Add-Member -NotePropertyName "Rules_Operator" -NotePropertyValue $rule.Operator
                    $setting | Add-Member -NotePropertyName "Rules_ConstantValue" -NotePropertyValue $rule.ConstantValue
                    $setting | Add-Member -NotePropertyName "Rules_ConstantDataType" -NotePropertyValue $rule.ConstantDataType
                }
            }
            
            # Add the setting to the settings array
            $settings += $setting
        }

        return $settings
    }
}