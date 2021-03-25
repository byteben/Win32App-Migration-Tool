
<#
.Synopsis
Created on:   21/03/2021
Created by:   Ben Whitmore
Filename:     Get-FileFromInternet.ps1

.Description
Function to download a file from the internet
#>
Function Get-FileFromInternet {
    Param (
        [String]$URI,
        [String]$Destination
    )

    Write-Log -Message "Function: Get-FileFromInternet was called" -Log "Main.log" 

    $File = $URI -replace '.*/'
    $FileDestination = Join-Path -Path $Destination -ChildPath $File
    Try {
        Invoke-WebRequest -UseBasicParsing -Uri $URI -OutFile $FileDestination -ErrorAction Stop
    }
    Catch {
        Write-Host "Warning: Error downloading the Win32 Content Prep Tool" -ForegroundColor Red
        $_
    }
}