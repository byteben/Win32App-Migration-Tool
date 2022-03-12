<#
.Synopsis
Created on:   12/03/22
Created by:   Ben Whitmore
Filename:     Get-AppList.ps1

.Description
Function to get Applications from ConfigMgr and filter results
#>
Function Get-AppList {
    Param (
        [Parameter(Mandatory = $True)]
        [String[]]$AppName,
        [Parameter(Mandatory = $False)]
        [Switch]$ExcludePMPC,
        [String]$ExcludeFilter,
        [Switch]$NoOGV

    )
 
    #Patch My PC Comment
    $PMPC_Comment = "Created by Patch My PC*"

    Write-Log -Message "Function: Get-App was called" -Log "Main.log" 

    If ($ExcludePMPC -and $ExcludeFilter -and $NoOGV) {
        Write-Log -Message "Get-CMApplication -Fast | Where-Object { $($_.LocalizedDisplayName) -like $($AppName) -and (-not($($_.LocalizedDisplayName) -like $($ExcludeFilter))) -and (-not($($_.LocalizedDescription) -like $($PMPC_Comment))) } | Select-Object -ExpandProperty LocalizedDisplayName" -Log "Main.log" 
        $ApplicationName = Get-CMApplication -Fast | Where-Object { $_.LocalizedDisplayName -like "$AppName" -and (-not($_.LocalizedDisplayName -like "$ExcludeFilter")) -and (-not($_.LocalizedDescription -like "$PMPC_Comment")) } | Select-Object -ExpandProperty LocalizedDisplayName 
    }
    If ($ExcludePMPC -and $ExcludeFilter -and (-not($NoOGV))) {
        Write-Log -Message "Get-CMApplication -Fast | Where-Object { $($_.LocalizedDisplayName) -like $($AppName) -and (-not($($_.LocalizedDisplayName) -like $($ExcludeFilter))) -and (-not($($_.LocalizedDescription) -like $($PMPC_Comment))) } | Select-Object -ExpandProperty LocalizedDisplayName | Sort-Object | Out-GridView -Passthru -Title ""Select an Application(s) to process the associated Deployment Types""" -Log "Main.log" 
        $ApplicationName = Get-CMApplication -Fast | Where-Object { $_.LocalizedDisplayName -like "$AppName" -and (-not($_.LocalizedDisplayName -like "$ExcludeFilter")) -and (-not($_.LocalizedDescription -like "$PMPC_Comment")) } | Select-Object -ExpandProperty LocalizedDisplayName | Sort-Object | Out-GridView -Passthru -Title "Select an Application(s) to process the associated Deployment Types"

    }
    If ($ExcludePMPC -and (-not($ExcludeFilter)) -and $NoOGV) {
        Write-Log -Message "Get-CMApplication -Fast | Where-Object { $($_.LocalizedDisplayName) -like $($AppName) -and (-not($($_.LocalizedDescription) -like $($PMPC_Comment))) } | Select-Object -ExpandProperty LocalizedDisplayName" -Log "Main.log" 
        $ApplicationName = Get-CMApplication -Fast | Where-Object { $_.LocalizedDisplayName -like "$AppName" -and (-not($_.LocalizedDescription -like "$PMPC_Comment")) } | Select-Object -ExpandProperty LocalizedDisplayName 

    }
    If ($ExcludePMPC -and (-not($ExcludeFilter)) -and (-not($NoOGV))) {
        Write-Log -Message "Get-CMApplication -Fast | Where-Object { $($_.LocalizedDisplayName) -like $($AppName) -and (-not($($_.LocalizedDescription) -like $($PMPC_Comment))) } | Select-Object -ExpandProperty LocalizedDisplayName | Sort-Object | Out-GridView -Passthru -Title ""Select an Application(s) to process the associated Deployment Types""" -Log "Main.log" 
        $ApplicationName = Get-CMApplication -Fast | Where-Object { $_.LocalizedDisplayName -like "$AppName" -and (-not($_.LocalizedDescription -like "$PMPC_Comment")) } | Select-Object -ExpandProperty LocalizedDisplayName | Sort-Object | Out-GridView -Passthru -Title "Select an Application(s) to process the associated Deployment Types"

    }
    If ((-not($ExcludePMPC)) -and $ExcludeFilter -and $NoOGV) {
        Write-Log -Message "Get-CMApplication -Fast | Where-Object { $($_.LocalizedDisplayName) -like $($AppName) -and (-not($($_.LocalizedDisplayName) -like $($ExcludeFilter))) } | Select-Object -ExpandProperty LocalizedDisplayName" -Log "Main.log" 
        $ApplicationName = Get-CMApplication -Fast | Where-Object { $_.LocalizedDisplayName -like "$AppName" -and (-not($_.LocalizedDisplayName -like "$ExcludeFilter")) } | Select-Object -ExpandProperty LocalizedDisplayName 

    }
    If ((-not($ExcludePMPC)) -and $ExcludeFilter -and (-not($NoOGV))) {
        Write-Log -Message "Get-CMApplication -Fast | Where-Object { $($_.LocalizedDisplayName) -like $($AppName) -and (-not($($_.LocalizedDisplayName) -like $($ExcludeFilter))) } | Select-Object -ExpandProperty LocalizedDisplayName | Sort-Object | Out-GridView -Passthru -Title ""Select an Application(s) to process the associated Deployment Types""" -Log "Main.log" 
        $ApplicationName = Get-CMApplication -Fast | Where-Object { $_.LocalizedDisplayName -like "$AppName" -and (-not($_.LocalizedDisplayName -like "$ExcludeFilter")) } | Select-Object -ExpandProperty LocalizedDisplayName | Sort-Object | Out-GridView -Passthru -Title "Select an Application(s) to process the associated Deployment Types"

    }
    If ((-not($ExcludePMPC)) -and (-not($ExcludeFilter)) -and $NoOGV) {
        Write-Log -Message "Get-CMApplication -Fast | Where-Object { $($_.LocalizedDisplayName) -like $($AppName) } | Select-Object -ExpandProperty LocalizedDisplayName" -Log "Main.log" 
        $ApplicationName = Get-CMApplication -Fast | Where-Object { $_.LocalizedDisplayName -like "$AppName" } | Select-Object -ExpandProperty LocalizedDisplayName 

    } 
    If ((-not($ExcludePMPC)) -and (-not($ExcludeFilter)) -and (-not($NoOGV))) {
        Write-Log -Message "Get-CMApplication -Fast | Where-Object { $($_.LocalizedDisplayName) -like $($AppName) } | Select-Object -ExpandProperty LocalizedDisplayName | Sort-Object | Out-GridView -PassThru -Title ""Select an Application(s) to process the associated Deployment Types""" -Log "Main.log" 
        $ApplicationName = Get-CMApplication -Fast | Where-Object { $_.LocalizedDisplayName -like "$AppName" } | Select-Object -ExpandProperty LocalizedDisplayName | Sort-Object | Out-GridView -Passthru -Title "Select an Application(s) to process the associated Deployment Types"

    } 

    Return $ApplicationName
}