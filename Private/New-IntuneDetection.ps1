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
        # Registry detection method
        function Add-SimpleSetting {
            param(
                [bool]$check32BitOn64System,
                [string]$keyPath,
                [string]$valueName,
                [string]$operator,
                [string]$version,
                [string]$detectionValue
                
            )
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
                [bool]$check32BitOn64System,
                [string]$detectionType,
                [string]$detectionValue,
                [string]$fileOrFolderName,
                [string]$operator,
                [string]$path
            )
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

                                # Create 64bit test
                                if ($setting.Is64Bit -eq $true) {
                                    $check32BitOn64System = [bool]$true
                                }
                                else {
                                    $check32BitOn64System = [bool]$false
                                }

                                # Check detection type
                                if ($setting.Rules_ConstantDataType -eq 'String') {
                                    $detectionType = 'string'
                                }
                                elseif ($setting.Rules_ConstantDataType -like '*version') {
                                    $detectionType = 'version'
                                } 

                                $jsonArray += Add-SimpleSetting `
                                    -check32BitOn64System $check32BitOn64System `
                                    -keyPath $regPath `
                                    -valueName $setting.ValueName `
                                    -operator $setting.Rules_Operator `
                                    -detectionType $detectionType `
                                    -detectionValue $setting.Rules_ConstantValue `
                            
                            }
                            'File' {
                                $jsonArray += Add-File -path $setting.Directory -fileName $setting.Name -is64Bit $setting.Is64Bit
                            }
                            'MSI' {
                                $jsonArray += Add-MSI -productCode $setting.ProductCode
                            }
                        }
                    }
                }

                # $jsonArray += Add-SimpleSetting -keyPath "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++" -valueName "DisplayVersion" -operator "Equals" -detectionValue "8.4.9" -is64Bit $true
                #$jsonArray += Add-File -path "C:\Windows" -fileName "Cheese.txt" -is64Bit $false
                #$jsonArray += Add-File -path "C:\Windows" -fileName "Cheese2.txt" -is64Bit $false
                #$jsonArray += Add-MSI -productCode "{00478901-CD97-4A20-8FF3-3276865A2B44}"
            
                # Convert the array to JSON
                $json = $jsonArray | ConvertTo-Json -Depth 10
            
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