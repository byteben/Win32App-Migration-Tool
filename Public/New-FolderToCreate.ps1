<#
.Synopsis
Created on:   21/03/2021
Created by:   Ben Whitmore
Filename:     New-FolderToCreate.ps1

.Description
Function to create a folder
#>
Function New-FolderToCreate {
    Param(
        [String]$Root,
        [String[]]$Folders
    )

    Write-Log -Message "Function: New-FolderToCreate was called" -Log "Main.log" 
    
    If (!($Root)) {
        Write-Log -Message "Error: No Root Folder passed to Function" -Log "Main.log"
        Write-Host "Error: No Root Folder passed to Function" -ForegroundColor Red
    }
    If (!($Folders)) {
        Write-Log -Message "Error: No Folder(s) passed to Function" -Log "Main.log"
        Write-Host "Error: No Folder(s) passed to Function" -ForegroundColor Red
    }

    ForEach ($Folder in $Folders) {
        #Create Folders
        Write-Log -Message "`$FolderToCreate = Join-Path -Path $($Root) -ChildPath $($Folder)" -Log "Main.log"
        $FolderToCreate = Join-Path -Path $Root -ChildPath $Folder
        If (!(Test-Path $FolderToCreate)) {
            Write-Host "Creating Folder ""$($FolderToCreate)""..." -ForegroundColor Cyan
            Try {
                New-Item -Path $FolderToCreate -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Log -Message "Folder ""$($FolderToCreate)"" created succesfully" -Log "Main.log"
                Write-Host "Folder ""$($FolderToCreate)"" created succesfully"
            }
            Catch {
                Write-Log -Message "Warning: Couldn't create ""$($FolderToCreate)"" folder" -Log "Main.log"
                Write-Host "Warning: Couldn't create ""$($FolderToCreate)"" folder" -ForegroundColor Red
            }
        }
        else {
            Write-Log -Message "Information: Folder ""$($FolderToCreate)"" already exsts. Skipping folder creation" -Log "Main.log"
            Write-Host "Information: Folder ""$($FolderToCreate)"" already exsts. Skipping folder creation" -ForegroundColor Magenta
        }
    }
} 