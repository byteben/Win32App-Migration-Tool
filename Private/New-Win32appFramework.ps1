<#
.Synopsis
Created on:   24/03/2024
Updated on:   02/04/2024
Created by:   Ben Whitmore
Filename:     New-Win32appFramework.ps1

.Description
Function to create a Win32 app JSON framework
Parameter descriptions reference https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-add

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

.PARAMETER InformationURL
Optionally, enter the URL of a website that contains information about this app. The URL 
appears in the company portal

.PARAMETER PrivacyURL
Optionally, enter the URL of a website that contains privacy information for this app. 
The URL appears in the company portal

.PARAMETER Notes
Enter any notes that you want to associate with this app

.PARAMETER Logo
Upload an icon that's associated with the app. This icon is displayed with the app when 
users browse through the company portal

#>
function New-IntuneWinFramework {
    param(
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = "Enter the unique app name as it appears in the company portal")]
        [string]$Name,
    
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = "Enter the app description for the company portal")]
        [string]$Description,
    
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = "Enter the publisher name of the app")]
        [string]$Publisher,
    
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 5, HelpMessage = "Enter the information URL of the app")]
        [string]$InformationURL,
    
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 6, HelpMessage = "Enter the privacy URL of the app")]
        [string]$PrivacyURL,
    
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 9, HelpMessage = "Enter any notes associated with the app")]
        [string]$Notes,
    
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 10, HelpMessage = "Upload the logo of the app")]
        [string]$Logo
    )
    begin {
        Write-Log -Message "Function: New-Win32appFramework was called" -Log "Main.log"
    }
    process {

    }
}