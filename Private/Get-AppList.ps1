<#
.Synopsis
Created on:   25/11/2023
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Get-AppList.ps1

.Description
Function to get applications from ConfigMgr and filter the results. One application is selected in the Out-GridView; use -NoOgv with a wildcard -AppName, or -AppId, to process several
If no applications are found or selected, nothing is returned.

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER AppName
The name of the application to filter on

.PARAMETER ExcludePMPC
Exclude Patch My PC applications

.PARAMETER ExcludeFilter
Exclude applications whose name matches the (wildcard) filter

.PARAMETER NoOgv
Do not display the results in an Out-GridView

.PARAMETER PmpcComment
The comment to exclude Patch My PC applications. Default comment is 'Created by Patch My PC*'

.PARAMETER AppId
One or more ConfigMgr application CI_IDs. When supplied, AppName and the Out-GridView are ignored and the applications with these Ids are returned
#>
function Get-AppList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The name of the application to get information for')]
        [String]$AppName = '',
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'Exclude Patch My PC applications')]
        [Switch]$ExcludePMPC,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Exclude applications whose name matches the filter')]
        [String]$ExcludeFilter,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'Do not display the results in an Out-GridView')]
        [Switch]$NoOgv,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 2, HelpMessage = 'The comment to exclude Patch My PC applications')]
        [String]$PmpcComment = 'Created by Patch My PC*',
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'The CI_ID(s) of the application(s) to return')]
        [string[]]$AppId
    )
    begin {
        Write-LogAndHost -Message "Function: Get-AppList was called" -LogId $LogId -ForegroundColor Cyan
        Write-LogAndHost -Message ("Filter State: ExcludeFilter: '{0}', ExcludePMPC: {1}, NoOgv: {2}, AppId: '{3}'" -f $ExcludeFilter, $ExcludePMPC, $NoOgv, ($AppId -join ',')) -LogId $LogId -ForegroundColor Cyan
    }
    process {
        $selectProperties = @(
            @{ Name = 'Id'; Expression = { $_.CI_ID.ToString() } }
            'LocalizedDisplayName', 'HasContent', 'NumberOfDeploymentTypes', 'IsDeployable', 'IsDeployed', 'DateCreated', 'DateLastModified', 'LastModifiedBy'
        )

        try {
            if ($AppId) {
                Write-LogAndHost -Message ("Invoking Get-CMApplication (fast) for Id(s) '{0}'" -f ($AppId -join ',')) -LogId $LogId -ForegroundColor Cyan
                $applicationResult = foreach ($id in $AppId) {
                    Get-CMApplication -Fast -Id $id | Select-Object -Property $selectProperties
                }
                $applicationResult = $applicationResult | Sort-Object LocalizedDisplayName
            }
            else {
                Write-LogAndHost -Message ("Invoking Get-CMApplication (fast) including apps like '{0}'" -f $AppName) -LogId $LogId -ForegroundColor Cyan

                $applicationResult = Get-CMApplication -Fast -Name "*$AppName*" |
                    Where-Object { (-not $ExcludeFilter) -or ($_.LocalizedDisplayName -notlike $ExcludeFilter) } |
                    Where-Object { (-not $ExcludePMPC) -or ($_.LocalizedDescription -notlike $PmpcComment) } |
                    Select-Object -Property $selectProperties |
                    Sort-Object LocalizedDisplayName

                if ($applicationResult -and -not $NoOgv) {
                    $applicationResult = $applicationResult | Out-GridView -Title 'Select the application to process' -OutputMode Single
                }
            }
        }
        catch {
            Write-LogAndHost -Message ("Could not get application information for '{0}'. {1}" -f $AppName, $_.Exception.Message) -LogId $LogId -Severity 3
            throw ("Could not get application information for '{0}'. {1}" -f $AppName, $_.Exception.Message)
        }

        if ($applicationResult) {
            return $applicationResult
        }
        Write-LogAndHost -Message 'No applications found or selected' -LogId $LogId -Severity 2
    }
}
