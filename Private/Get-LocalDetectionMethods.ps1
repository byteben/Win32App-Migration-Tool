<#
.Synopsis
Created on:   17/02/2024
Update on:    17/02/2024
Created by:   Ben Whitmore
Filename:     Get-LocalDetectionMethods.ps1

.Description
Function to get the local detection methods from the detection methods xml object

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER XMLContent
The XML content object to extract the detection methods from
#>
function Get-DetectionMethod {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The id of the application(s) to get information for')]
        [object]$XMLObject
    )
    begin {

        #  Load XML from a file or a variable
        [xml]$xmlDocument = $XMLObject
        
    }
    process {

        # Create an array to hold the settings objects
        $settings = @()

        # Extract SimpleSetting elements
        $XmlDocument.EnhancedDetectionMethod.Settings.SimpleSetting | ForEach-Object {
            $simpleSetting = @{
                Type        = "SimpleSetting"
                LogicalName = $_.LogicalName
                DataType    = $_.DataType
                Is64Bit     = $_.RegistryDiscoverySource.Is64Bit
                Depth       = $_.RegistryDiscoverySource.Depth
                Hive        = $_.RegistryDiscoverySource.Hive
                Key         = $_.RegistryDiscoverySource.Key
                ValueName   = $_.RegistryDiscoverySource.ValueName
            }
            $settings += New-Object PSObject -Property $simpleSetting
        }

        # Extract File elements
        $XmlDocument.EnhancedDetectionMethod.Settings.File | ForEach-Object {
            $file = @{
                Type        = "File"
                LogicalName = $_.LogicalName
                Is64Bit     = $_.Is64Bit
                Path        = $_.Path
                Filter      = $_.Filter
            }
            $settings += New-Object PSObject -Property $file
        }

        # Extract MSI elements
        $XmlDocument.EnhancedDetectionMethod.Settings.MSI | ForEach-Object {
            $msi = @{
                Type        = "MSI"
                LogicalName = $_.LogicalName
                ProductCode = $_.ProductCode
            }
            $settings += New-Object PSObject -Property $msi
        }

        return $settings
    }
}