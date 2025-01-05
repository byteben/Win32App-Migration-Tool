<#
.Synopsis
Created on:   17/03/2024
Update on:    04/01/2025
Created by:   Ben Whitmore
Filename:     New-IntuneDetection.ps1

.Description
Function to get the local detection methods from the detection methods xml object

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER LocalSettings
The local detection method settings array to convert to JSON

.PARAMETER Script
The local detection method script to prepare
#>

function New-IntuneDetectionMethod {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The local detection method settings array to convert to JSON', ParameterSetName = 'Methods')]
        [object]$LocalSettings,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 1, HelpMessage = 'The local detection method script to prepare', ParameterSetName = 'Methods')]
        [object]$Script
    )
    begin {

        # Helper functions to create the JSON objects
        # Function to convert empty strings to $null in JSON
        function Convert-EmptyStringToNullInJson {
            param (
                [Parameter(Mandatory = $true)]
                [string]$Json
            )
            
            # Convert the JSON to objects
            $objects = $Json | ConvertFrom-Json
            
            function Update-Object {
                param (
                    $Object
                )
                
                # Check key values for empty strings and convert to $null
                foreach ($property in $Object.PSObject.Properties) {
                    if ($property.Value -is [string] -and $property.Value -eq '') {
                        $property.Value = $null
                    }
                    elseif ($property.Value -is [PSCustomObject] -or $property.Value -is [array]) {
                        Update-Object -Object $property.Value
                    }
                }
            }
            
            # Process each object
            foreach ($obj in $objects) {
                Update-Object -Object $obj
            }
            
            # Return the new JSON
            $newJson = $objects | ConvertTo-Json -Depth 5
            return $newJson
        }
        
        # Registry detection method
        function Add-SimpleSetting {
            param(
                [string]$is64Bit,
                [string]$keyPath,
                [string]$valueName,
                [string]$operator,
                [string]$version,
                [string]$detectionType,
                [string]$detectionValue
            )
            
            # Prepare 64bit check
            if ($is64Bit -eq 'true') {
                $check32BitOn64System = [bool]$false
            }
            else {
                $check32BitOn64System = [bool]$true
            }

            # Set the detection type
            $detectionType = $detectionType.ToLower()

            # Prepare operands for the Intune detection method
            switch ($operator) {
                'Equals' {
                    $operator = 'equal'
                }
                'NotEquals' {
                    $operator = 'notEquals'
                }
                'GreaterThan' {
                    $operator = 'greaterThan'
                }
                'GreaterEquals' {
                    $operator = 'greaterThanOrEqual'
                }
                'LessThan' {
                    $operator = 'lessThan'
                }
                'LessEquals' {
                    $operator = 'lessThanOrEqual'
                }
                'Match' {
                    $operator = 'match'
                }
                'NotMatch' {
                    $operator = 'notMatch'
                }
                'Contains' {
                    $operator = 'contains'
                }
                'NotContains' {
                    $operator = 'notContains'
                }
                'BeginsWith' {
                    $operator = 'beginsWith'
                }
                'EndsWith' {
                    $operator = 'endsWith'
                }
            }

            # Prepare detection types for the Intune detection method
            switch ($detectionType) {
                'Int64' {
                    $detectionType = 'integer'
                }
            }

            $object = [PSCustomObject]@{
                '@odata.type'          = '#microsoft.graph.win32LobAppRegistryDetection'
                'check32BitOn64System' = $check32BitOn64System
                'detectionType'        = $detectionType
                'detectionValue'       = $detectionValue
                'keyPath'              = $keyPath
                'operator'             = $operator
                'valueName'            = $valueName
            }
            return $object
        }
        
        # File or Folder detection method
        function Add-File {
            param(
                [string]$is64Bit,
                [string]$detectionType,
                [string]$detectionValue,
                [string]$fileOrFolderName,
                [string]$operator,
                [string]$path
            )

            # Prepare 64bit check
            if ($is64Bit -eq 'true') {
                $check32BitOn64System = [bool]$false
            }
            else {
                $check32BitOn64System = [bool]$true
            }

            # Set the detection type
            $detectionType = $detectionType.ToLower()

            # Prepare operands for the Intune detection method
            switch ($operator) {
                'Equals' {
                    $operator = 'equals'
                }
                'NotEquals' {
                    $operator = 'notEquals'
                }
                'GreaterThan' {
                    $operator = 'greaterThan'
                }
                'GreaterEquals' {
                    $operator = 'greaterThanOrEqual'
                }
                'LessThan' {
                    $operator = 'lessThan'
                }
                'LessEquals' {
                    $operator = 'lessThanOrEqual'
                }
                'Match' {
                    $operator = 'match'
                }
                'NotMatch' {
                    $operator = 'notMatch'
                }
                'Contains' {
                    $operator = 'contains'
                }
                'NotContains' {
                    $operator = 'notContains'
                }
                'BeginsWith' {
                    $operator = 'beginsWith'
                }
                'EndsWith' {
                    $operator = 'endsWith'
                }
            }

            # Check detection types
            if ($operator -eq 'notEquals' -and $detectionValue -eq 0 -and $detectionType -eq 'int64') {
                $operator = 'notConfigured'
                $detectionType = 'exists'
                $detectionValue = $null
            }

            $object = [PSCustomObject]@{
                '@odata.type'          = '#microsoft.graph.win32LobAppFileSystemDetection'
                'check32BitOn64System' = $check32BitOn64System
                'detectionType'        = $detectionType
                'detectionValue'       = $detectionValue
                'fileOrFolderName'     = $fileOrFolderName
                'operator'             = $operator
                'path'                 = $path

            }
            return $object
        }
        
        # MSI detection method
        function Add-MSI {
            param(
                [string]$productCode,
                [string]$productVersion,
                [string]$productVersionOperator
            )

            # Prepare operands for the Intune detection method
            switch ($productVersionOperator) {
                'Equals' {
                    $productVersionOperator = 'equals'
                }
                'NotEquals' {
                    $productVersionOperator = 'notEquals'
                }
                'GreaterThan' {
                    $productVersionOperator = 'greaterThan'
                }
                'GreaterEquals' {
                    $productVersionOperator = 'greaterThanOrEqual'
                }
                'LessThan' {
                    $productVersionOperator = 'lessThan'
                }
                'LessEquals' {
                    $productVersionOperator = 'lessThanOrEqual'
                }
            }

            # Check if the product version is not configured
            if ( -not $productVersion -and -not $productVersionOperator) {
                $productVersion = $null
                $productVersionOperator = 'notConfigured'
            }

            $object = [PSCustomObject]@{
                '@odata.type'            = '#microsoft.graph.win32LobAppProductCodeDetection'
                'productCode'            = $productCode
                'productVersion'         = $productVersion
                'productVersionOperator' = $productVersionOperator
            }
            return $object
        }
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'Methods') {
            if ($PSBoundParameters.Keys.Count -gt 1) {
                Write-LogAndHost -Message 'Only one parameter is allowed in parameter set "Methods". Choose either "LocalSettings" or "Script"' -LogId $LogId -Severity 3
                return
            }
            else {
                if ($PSBoundParameters['LocalSettings']) {
                    $jsonArray = @()
    
                    foreach ($setting in $LocalSettings) {
                        switch ($setting.Type) {
                            'SimpleSetting' {

                                # Create the registry key path
                                $regPath = Join-Path -Path $setting.Hive -ChildPath $setting.Key -ErrorAction SilentlyContinue
    
                                # Add the registry detection object
                                $jsonArray += Add-SimpleSetting `
                                    -is64Bit $setting.is64Bit `
                                    -keyPath $regPath `
                                    -valueName $setting.ValueName `
                                    -operator $setting.Rules_Operator `
                                    -detectionType $setting.Rules_ConstantDataType `
                                    -detectionValue $setting.Rules_ConstantValue
                            }
                            'File' {
                                $jsonArray += Add-File `
                                    -is64Bit $setting.is64Bit `
                                    -detectionType $setting.Rules_ConstantDataType `
                                    -detectionValue $setting.Rules_ConstantValue `
                                    -fileOrFolderName $setting.Filter `
                                    -operator $setting.Rules_Operator `
                                    -path $setting.Path
                            }
                            'MSI' {
                                $jsonArray += Add-MSI `
                                    -productCode $setting.ProductCode `
                                    -ProductVersion $setting.Rules_ConstantValue `
                                    -ProductVersionOperator $setting.Rules_Operator
                            }
                            default {
                                Write-LogAndHost -Message "Unhandled detection type: $($setting.Type)" -LogId $LogId -Severity 3
                            }
                        }
                    }
    
                    # Convert to JSON
                    $json = $jsonArray | ConvertTo-Json -Depth 5
                    Convert-EmptyStringToNullInJson -Json $json
                }
                else {
                    Write-LogAndHost -Message 'No settings were passed to the function' -LogId $LogId -Severity 3
                    return
                }
            }
        }
    }  
}  