
<#
.Synopsis
Created on:   28/10/2023
Updated on:   01/01/2025
Created by:   Ben Whitmore
Filename:     Get-FileFromInternet.ps1

.Description
Function to download a file from the internet

.PARAMETER LogID
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER Uri
The URI of the file to download

.PARAMETER Destination
The destination folder to download the file to
#>
function Get-FileFromInternet {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The URI of the file to download')]
        [String]$Uri,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'The destination folder to download the file to')]
        [String]$Destination
    )

    begin {
        Write-LogAndHost -Message 'Function: Get-FileFromInternet was called' -LogId $LogId -ForegroundColor Cyan
        Write-LogAndHost -Message ("Attempting to download the file from '{0}'" -f $Uri) -LogId $LogId -ForegroundColor Cyan
        Write-LogAndHost -Message ("File destination will be '{0}'" -f $Destination) -LogId $LogId -ForegroundColor Cyan
    }

    process {

        # Test the Uri is valid
        try {
            $uriRequest = Invoke-WebRequest -Method Get -UseBasicParsing -URI $Uri -ErrorAction SilentlyContinue
            $statusCode = $uriRequest.StatusCode
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.Value__
            Write-LogAndHost -Message ("It looks like the Uri '{0}' is invalid. Error '{1}" -f $Uri, $statusCode) -LogId $LogId -Severity 3

            throw
        }

        # If the URL is valid, attempt to download the file otherwise break and warn
        if ($statusCode -eq 200) {
            try {

                Write-LogAndHost -Message ("Response '{0}' received'. Attempting download...'" -f $statusCode) -LogId $LogId -ForegroundColor Cyan
                Invoke-WebRequest -UseBasicParsing -Method Get -Uri $Uri -OutFile $Destination -ErrorAction SilentlyContinue

                if (Test-Path -Path $fileDestination) {
                    Write-LogAndHost -Message ("File download successful. File saved to '{0}'" -f $fileDestination) -LogId $LogId -ForegroundColor Green
                }
                else {
                    Write-LogAndHost -Message ("The download was interrupted or an error occured moving the file to '{0}'" -f $Uri) -LogId $LogId -Severity 3
                }
            }
            catch {

                # Error downloading the file
                Write-LogAndHost -Message ("Error downloading file '{0}'" -f $Uri) -LogId $LogId -Severity 3

                throw
            }
        }
        else {
            Write-LogAndHost -Message ("URL Does not exists or the website is down. Status Code '{0}'" -f $statusCode) -LogId $LogId -Severity 3
            
            throw
        }
    }
}