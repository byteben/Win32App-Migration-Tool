<#
.Synopsis
Created on:   05/11/23
Updated on:   16/12/23
Created by:   Ben Whitmore
Filename:     Export-Csv.ps1

.Description
Function to export data to a csv file.
If the Csv exists, it will be rolled over to a new file with a timestamp appended to the filename

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER Data
The data, as a PSCustomObject, to export

.PARAMETER Name
The name of the data to export

.PARAMETER Path
The path to export the data to
#>
function Export-CsvDetails {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, HelpMessage = 'The name of the data to export')]
        [string]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1, HelpMessage = 'The data, as a PSCustomObject, to export')]
        [pscustomobject]$Data,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 2, HelpMessage = 'The path to export the data to')]
        [string]$Path

    )

    begin {

        # Specify CSV archive folder name
        $archiveFolder = 'Old'

        # Log the export
        Write-Log -Message ("Exporting '{0}' information to '{1}\{0}.csv'" -f $Name, $Path) -LogId $LogId
        Write-Host ("Exporting '{0}' information to '{1}\{0}.csv'" -f $Name, $Path) -ForegroundColor Cyan

        # Build path string
        $fullPath = Join-Path -Path $Path -ChildPath ("{0}.csv" -f $Name)
        $archivePath = Join-Path -Path $Path -ChildPath $archiveFolder

        # Rollover the csv if it already exists from a previous run
        if (Test-Path -Path $fullPath) {
            Write-Log -Message ("'{0}' already exists, rolling over csv" -f $fullPath) -LogId $LogId -Severity 2
            Write-Host ("'{0}' already exists, rolling over csv" -f $fullPath) -ForegroundColor Yellow
            $date = Get-Date -Format 'yyyyMMddHHmmss'
            $pathRename = $fullPath -replace '.csv', ''

            # Attempt to rename the file, if it fails continue but the file will be overwritten
            try {
                $newPath = ("{0}_{1}.csv" -f $pathRename, $date)
                Rename-Item -Path $fullPath -NewName $newPath
                
                # Create the archive folder if it does not exist
                if (-not (Test-Path -Path $archivePath)){
                    New-FolderToCreate -Root $Path -FolderNames $archiveFolder
                }

                # Move the old CSV into the archive folder
                Move-Item -Path $newPath -Destination $archivePath -Force

                Write-Log -Message ("Previous Csv rolled over to '{0}\{1}_{2}.csv'" -f $archivePath, $pathRename, $date) -LogId $LogId
                Write-Host ("Previous Csv rolled over to '{0}\{1}_{2}.csv'" -f $archivePath, $pathRename, $date) -ForegroundColor Green
            }
            catch {
                Write-Log -Message ("Failed to rollover '{0}'. Csv will be overwritten." -f $Path) -LogId $LogId -Severity 3
                Write-Host ("Failed to rollover '{0}'. Csv will be overwritten." -f $Path) -ForegroundColor Red
            }
        }
    }
    
    process {

        # Export the data to a csv file
        foreach ($object in $Data) {
            try {

                # Check if the file already exists to handle the header correctly
                if (-not (Test-Path -Path $fullPath) ) {

                    # Include headers if the file doesn't exist
                    $object | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $fullPath
                }
                else {

                    # If the file exists, skip the header line
                    $object | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File -FilePath $fullPath -Append
                }
            }
            catch {
                Write-Log -Message ("Failed to export '{0}' information to '{1}'" -f $Type, $fullPath) -LogId $LogId -Severity 3
                Write-Host ("Failed to export '{0}' information to '{1}'" -f $Type, $fullPath) -ForegroundColor Red
                Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
                throw
            }
        }
    }
}
