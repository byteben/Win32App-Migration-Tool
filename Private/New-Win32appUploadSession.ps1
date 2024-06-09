<#
.Synopsis
Created on:   24/03/2024
Updated on:   02/04/2024
Created by:   Ben Whitmore
Filename:     New-Win32appUploadSession.ps1

.Description
Function to create a new upload session to get the app id for the Win32 app

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

#>
function New-IntuneWinUploadSession {
    param(
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = "Enter the unique app name as it appears in the company portal")]
        [string]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = "Enter the app description for the company portal")]
        [string]$Description,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = "Enter the publisher name of the app")]
        [string]$Publisher,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 3, HelpMessage = "Enter the URL to create the upload session")]
        [string]$Url = 'https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps'
    )

    begin {

        Write-Log -Message "Function: New-Win32appUploadSession was called" -LogId $LogId
    }

    process {
            
        $body = [ordered]@{
            "displayName" = $Name
            "description" = $Description
            "publisher"   = $Publisher
        }

        try {
            $response = Invoke-RestMethod -Uri $url -Method Post -Headers $global:authHeader -Body $body
            return $response.id
        }
        catch {
            throw $_.Exception
        }
    }
}