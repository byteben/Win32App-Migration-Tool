<#
.Synopsis
Created on:   09/06/2024
Updated on:   01/01/2025
Created by:   Ben Whitmore
Filename:     New-IntuneWinContentRequest.ps1

.Description
Function to create a new content request for an IntuneWin package
Properties for content request can be found at https://learn.microsoft.com/en-us/graph/api/resources/intune-apps-mobileappcontentfile?view=graph-rest-1.0

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER ContentVersion
The version of the content to be uploaded

.PARAMETER Name
The intunewin file name

.PARAMETER SizeEncrypted
The compressed size of the content to be uploaded

.PARAMETER SizeUnencrypted
The uncompressed size of the content to be uploaded

.PARAMETER IsDependency
Is this content a dependency

#>
function New-IntuneWinContentRequest {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The intunewin file name')]
        [string]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'The compressed size of the content to be uploaded')]
        [int64]$SizeEncrypted,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = 'The uncompressed size of the content to be uploaded')]
        [int64]$SizeUnencrypted,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 4, HelpMessage = 'Is this content a dependency')]
        [bool]$IsDependency = $false,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name
    )
    begin {

        Write-LogAndHost -Message "Function: new-IntuneWinContentRequest was called" -Log "Main.log" -ForegroundColor Cyan

    }
    process {

        # Create the IntuneWinContentRequest Json
        try {
            $intuneWinContentRequest = [ordered]@{
                "@odata.type"   = "#microsoft.graph.mobileAppContentFile"
                "name"          = $Name
                "size"          = $SizeUnencrypted
                "sizeEncrypted" = $SizeEncrypted
                "isDependency"  = $IsDependency
                "manifest"      = $null
            }
        }
        catch {
            Write-LogAndHost -Message "An error occurred while creating the IntuneWinContentRequest" -LogId $LogId -Severity 3

            return $false
        }

        Write-LogAndHost -Message ("{0}" -f ($intuneWinContentRequest | ConvertTo-Json -Depth 5 -Compress) ) -LogId $LogId -ForegroundColor Green

        return $intuneWinContentRequest
    }
}