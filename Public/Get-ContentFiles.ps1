<#
.Synopsis
Created on:   21/03/2021
Created by:   Ben Whitmore
Filename:     Get-ContentFiles.ps1

.Description
Function to get content
#>
Function Get-ContentFiles {
    Param (
        [String]$Source,
        [String]$Destination
    )

    Write-Log -Message "Function: Get-ContentFiles was called" -Log "Main.log" 
    Write-Log -Message "Padding $($Source) in case content path has spaces. Robocopy demand space at end of Source String" -Log "Main.log" 
    $SourcePadded = "`"" + $Source + " `""
    Write-Log -Message "Padding $($Destination) in case content path has spaces. Robocopy demand space at end of Destination String" -Log "Main.log" 
    $DestinationPadded = "`"" + $Destination + " `""

    Try {
        Write-Log -Message "`$Log = Join-Path -Path $($WorkingFolder_Logs) -ChildPath ""Main.Log""" -Log "Main.log" 
        $Log = Join-Path -Path $WorkingFolder_Logs -ChildPath "Main.Log"
        Write-Log -Message "Robocopy.exe $($SourcePadded) $($DestinationPadded) /MIR /E /Z /R:5 /W:1 /NDL /NJH /NJS /NC /NS /NP /V /TEE  /UNILOG+:$($Log)" -Log "Main.log" 
        $Robo = Robocopy.exe $SourcePadded $DestinationPadded /MIR /E /Z /R:5 /W:1 /NDL /NJH /NJS /NC /NS /NP /V /TEE /UNILOG+:$Log
        $Robo

        If ((Get-ChildItem -Path $Destination | Measure-Object).Count -eq 0 ) {
            Write-Log -Message "Error: Could not transfer content from ""$($Source)"" to ""$($Destination)""" -Log "Main.log" 
            Write-Host "Error: Could not transfer content from ""$($Source)"" to ""$($Destination)""" -ForegroundColor Red
        }
    }
    Catch {
        Write-Log -Message "Error: Could not transfer content from ""$($Source)"" to ""$($Destination)""" -Log "Main.log" 
        Write-Host "Error: Could not transfer content from ""$($Source)"" to ""$($Destination)""" -ForegroundColor Red
    }
}