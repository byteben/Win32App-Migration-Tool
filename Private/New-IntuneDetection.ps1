<#
.Synopsis
Created on:   17/03/2024
Update on:    17/03/2024
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
        function ConvertTo-JsonWithEmptyStringsAsNulls {
            param (
                [Parameter(ValueFromPipeline = $true)]
                [object]$inputObject,
                [int]$depth = 2
            )
        
            begin {
                # Function to recursively process objects and arrays to convert empty strings to $null
                function ProcessObject {
                    param(
                        $object
                    )

                    if ($object -is [array]) {
                        $processedArray = @()

                        # Recursively process each item in the array
                        foreach ($item in $object) {
                            $processedArray += ProcessObject -Object $item  
                        }
                        return $processedArray
                    }
                    elseif ($object -is [PSCustomObject]) {
                        $processedObject = New-Object PSObject
                        foreach ($prop in $object.PSObject.Properties) {
                            $value = $prop.Value
                            if ($value -is [string] -and $value -eq "") {

                                # Convert empty strings to $null
                                $value = $null  
                            }
                            elseif ($value -is [array] -or $value -is [PSCustomObject]) {

                                # Recursively process nested objects or arrays
                                $value = ProcessObject -object $value  
                            }
                            $processedObject | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $value
                        }
                        return $processedObject
                    }
                    else {
                        
                        # Return the object as is if it's not an array or a custom object
                        return $object  
                    }
                }
            }
        
            process {
                $processedInput = ProcessObject -Object $inputObject
                return $processedInput | ConvertTo-Json -Depth $Depth
            }
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

            # Check if more than one parameter was passed within the parameter set
        
            if ($PSBoundParameters.Keys.Count -gt 1) {
                Write-Log -Message 'Only one parameter is allowed in parameter set "Methods". Choose either "LocalSettings" or "Script"' -LogId $LogId -Severity 3
                Write-Host 'Only one parameter is allowed in parameter set "Methods". Choose either "LocalSettings" or "Script"' -ForegroundColor Red
                return
            }
            else {

                # Check if the LocalSettings or script parameter was passed
                if ($PSBoundParameters['LocalSettings']) {
                    $settings = $Settings
                }
                elseif ($PSBoundParameters['Script']) {
                }
                else {
                    Write-Log -Message 'No settings were passed to the function' -LogId $LogId -Severity 3
                    Write-Host 'No settings were passed to the function' -ForegroundColor Red
                    return
                }

                # Check if the LocalSettings parameter was passed

                if ($PSBoundParameters['LocalSettings']) {

                    # Create an empty array to store the JSON objects
                    $jsonArray = @()

                    foreach ($setting in $Localsettings) {

                        Switch ($setting.Type) {
                            'SimpleSetting' {

                                # Create the key path
                                $regPath = Join-Path -Path $setting.Hive -ChildPath $setting.Key -ErrorAction SilentlyContinue

                                $jsonArray += Add-SimpleSetting `
                                    -is64Bit $is64Bit `
                                    -keyPath $regPath `
                                    -valueName $setting.ValueName `
                                    -operator $setting.Rules_Operator `
                                    -detectionType $setting.Rules_ConstantDataType `
                                    -detectionValue $setting.Rules_ConstantValue
                            }
                            'File' {

                                $jsonArray += Add-File `
                                    -is64Bit $is64Bit `
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
                                    -ProductVersionOperator $setting.Rules_Operator `
                            
                            }
                        }
                    }
                }
            
                # Convert the array to JSON
                $json = $jsonArray | ConvertTo-JsonWithEmptyStringsAsNulls -Depth 10
            
                # Display or output the JSON
                $json
            }
        }
        else {
            Write-Log -Message 'At least one parameter from parameter set "Methods" is required. Choose either "LocalSettings" or "Script"' -LogId $LogId -Severity 3
            Write-Host 'At least one parameter from parameter set "Methods" is required. Choose either "LocalSettings" or "Script"' -ForegroundColor Red
            return
        }
    }
}