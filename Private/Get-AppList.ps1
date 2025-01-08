<#
.Synopsis
Created on:   25/11/2023
Updated on:   01/01/2025
Created by:   Ben Whitmore
Filename:     Get-AppList.ps1

.Description
Function to get applications from ConfigMgr and filter the results

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER AppName
The name of the application to filter on

.PARAMETER ExcludePMPC
Exclude Patch My PC applications

.PARAMETER ExcludeFilter
Exclude applications that match the filter

.PARAMETER NoOgv
Do not display the results in an Out-GridView

.PARAMETER PmpcComment
The comment to exclude Patch My PC applications. Default comment is 'Created by Patch My PC*'
#>
function Get-AppList {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The name of the application to get information for')]
        [String]$AppName,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'Exclude Patch My PC applications')]
        [Switch]$ExcludePMPC,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 1, HelpMessage = 'The name of the application to get information for')]
        [String]$ExcludeFilter,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'Do not display the results in an Out-GridView')]
        [Switch]$NoOgv,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 2, HelpMessage = 'The comment to exclude Patch My PC applications')]
        [String]$PmpcComment = 'Created by Patch My PC*'

    )
    begin {

        Write-LogAndHost -Message "Function: Get-AppList was called" -LogId $LogId -ForegroundColor Cyan

        # Check if the ExcludeFilter parameter is null or empty. If it is, set it to $false so we can use it in the switch statement
        if ([string]::IsNullOrWhiteSpace($ExcludeFilter)) {
            $ExcludeFilter = $false
        }
        Write-LogAndHost -message "Filter State: ExcludeFilter: $ExcludeFilter, ExcludePMPC: $ExcludePMPC, NoOgv: $NoOgv" -logid $LogId -foregroundcolor cyan

    }
    process {

        try {
            
            # Check the parameters passed to select the correct switch option
            switch ($ExcludePMPC) {
                $true {
                    switch ($ExcludeFilter) {
                        $true {
                            switch ($NoOgv) {
                                $true {
                                    Write-LogAndHost -Message ("Invoking Get-CMApplication (fast) including apps like '{0}' excluding apps like '{1}' and where the comment field is like '{2}' (NoOgv parameter passed)" -f $AppName, $ExcludeFilter, $Pmpc_Comment) -LogId $LogId -ForegroundColor Cyan
                                    $applicationResult = Get-CMApplication -Fast -Name "*$AppName*" | Where-Object { (-not ($_.LocalizedDisplayName -like "$ExcludeFilter") ) -and (-not ($_.LocalizedDescription -like "$Pmpc_Comment") ) } | Select-Object @{ Name = 'Id'; Expression = { $_.CI_ID.toString() } }, LocalizedDisplayName, HasContent, NumberOfDeploymentTypes, IsDeployable, IsDeployed, DateCreated, DateLastModified, LastModifiedBy | Sort-Object LocalizedDisplayName
                                }
                                $false {
                                    Write-LogAndHost -Message ("Invoking Get-CMApplication (fast) including apps like '{0}' excluding apps like '{1}'" -f $AppName, $ExcludeFilter) -LogId $LogId -ForegroundColor Cyan
                                    $applicationResult = Get-CMApplication -Fast -Name "*$AppName*" | Where-Object { (-not ($_.LocalizedDisplayName -like "$ExcludeFilter") ) -and (-not ($_.LocalizedDescription -like "$Pmpc_Comment") ) } | Select-Object @{ Name = 'Id'; Expression = { $_.CI_ID.toString() } }, LocalizedDisplayName, HasContent, NumberOfDeploymentTypes, IsDeployable, IsDeployed, DateCreated, DateLastModified, LastModifiedBy | Sort-Object LocalizedDisplayName | Out-GridView -Title 'Select an application(s) to process the associated deployment types' -OutputMode Single
                                }
                            }
                        }
                        $false {
                            switch ($NoOgv) {
                                $true {
                                    Write-LogAndHost -Message ("Invoking Get-CMApplication (fast) including apps like '{0}' where the comment field is like '{1}' (NoOgv parameter passed)" -f $AppName, $Pmpc_Comment) -LogId $LogId -ForegroundColor Cyan
                                    $applicationResult = Get-CMApplication -Fast -Name "*$AppName*" | Where-Object { (-not ($_.LocalizedDescription -like "$Pmpc_Comment") ) } | Select-Object @{ Name = 'Id'; Expression = { $_.CI_ID.toString() } }, LocalizedDisplayName, HasContent, NumberOfDeploymentTypes, IsDeployable, IsDeployed, DateCreated, DateLastModified, LastModifiedBy | Sort-Object LocalizedDisplayName
                                }
                                $false {
                                    Write-LogAndHost -Message ("Invoking Get-CMApplication (fast) including apps like '{0}' where the comment field is like '{1}'" -f $AppName, $Pmpc_Comment) -LogId $LogId -ForegroundColor Cyan
                                    $applicationResult = Get-CMApplication -Fast -Name "*$AppName*" | Where-Object { (-not ($_.LocalizedDescription -like "$Pmpc_Comment") ) } | Select-Object @{ Name = 'Id'; Expression = { $_.CI_ID.toString() } }, LocalizedDisplayName, HasContent, NumberOfDeploymentTypes, IsDeployable, IsDeployed, DateCreated, DateLastModified, LastModifiedBy | Sort-Object LocalizedDisplayName | Out-GridView -Title 'Select an application(s) to process the associated deployment types' -OutputMode Single
                                }
                            }
                        }
                    }
                }
                $false {
                    switch ($ExcludeFilter) {
                        $true {
                            switch ($NoOgv) {
                                $true {
                                    Write-LogAndHost -Message ("Invoking Get-CMApplication (fast) including apps like '{0}' excluding apps like '{1}' (NoOgv parameter passed)" -f $AppName, $ExcludeFilter) -LogId $LogId -ForegroundColor Cyan
                                    $applicationResult = Get-CMApplication -Fast -Name "*$AppName*" | Where-Object { (-not($_.LocalizedDisplayName -like "$ExcludeFilter")) } | Select-Object @{ Name = 'Id'; Expression = { $_.CI_ID.toString() } }, LocalizedDisplayName, HasContent, NumberOfDeploymentTypes, IsDeployable, IsDeployed, DateCreated, DateLastModified, LastModifiedBy | Sort-Object LocalizedDisplayName
                                }
                                $false {
                                    Write-LogAndHost -Message ("Invoking Get-CMApplication (fast) including apps like '{0}' excluding apps like '{1}'" -f $AppName, $ExcludeFilter) -LogId $LogId -ForegroundColor Cyan
                                    $applicationResult = Get-CMApplication -Fast -Name "*$AppName*" | Where-Object { ( -not ($_.LocalizedDisplayName -like "$ExcludeFilter") ) } | Select-Object @{ Name = 'Id'; Expression = { $_.CI_ID.toString() } }, LocalizedDisplayName, HasContent, NumberOfDeploymentTypes, IsDeployable, IsDeployed, DateCreated, DateLastModified, LastModifiedBy | Sort-Object LocalizedDisplayName | Out-GridView -Title 'Select an Application(s) to process the associated deployment types' -OutputMode Single
                                }
                            }
                        }
                        $false {
                            switch ($NoOgv) {
                                $true {
                                    write-host "hank"
                                    Write-LogAndHost -Message ("Invoking Get-CMApplication (fast) including apps like '{0}' (NoOgv parameter passed)" -f $AppName) -LogId $LogId -ForegroundColor Cyan
                                    $applicationResult = Get-CMApplication -Fast -Name "*$AppName*" | Select-Object @{ Name = 'Id'; Expression = { $_.CI_ID.toString() } }, LocalizedDisplayName, HasContent, NumberOfDeploymentTypes, IsDeployable, IsDeployed, DateCreated, DateLastModified, LastModifiedBy | Sort-Object LocalizedDisplayName
                                }
                                $false {
                                    Write-LogAndHost -Message ("Invoking Get-CMApplication (fast) including apps like '{0}'" -f $AppName) -LogId $LogId -ForegroundColor Cyan
                                    $applicationResult = Get-CMApplication -Fast -Name "*$AppName*" | Select-Object @{ Name = 'Id'; Expression = { $_.CI_ID.toString() } }, LocalizedDisplayName, HasContent, NumberOfDeploymentTypes, IsDeployable, IsDeployed, DateCreated, DateLastModified, LastModifiedBy | Sort-Object LocalizedDisplayName | Out-GridView -Title 'Select an application to process the associated deployment types' -OutputMode Single
                                }
                            }
                        }
                    }
                }
            }

            # Check if any applications were selected or found
            if ($applicationResult) {
                
                return $applicationResult
                
            }
            else {
                Write-LogAndHost -Message "No applications selected" -LogId $LogId -ForegroundColor Yellow
            }
        }
        catch {
            Write-LogAndHost -Message ("Could not get application information for '{0}'" -f $AppName) -LogId $LogId -Severity 3
            Get-ScriptEnd -LogId $LogId -ErrorMessage $_.Exception.Message
        }
    }
}