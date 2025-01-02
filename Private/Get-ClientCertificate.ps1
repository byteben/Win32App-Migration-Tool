<#
.Synopsis
Created on:   03/04/2024
Updated on:   01/01/2025
Created by:   Ben Whitmore
Filename:     Get-ClientCertificate.ps1

.Description
Function to get a client certificate from the local certificate store

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER Thumbprint
The thumbprint of the client certificate to get.
#>
function Get-ClientCertificate {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, HelpMessage = 'Thumbprint of the client certificate to get')]
        [string]$Thumbprint
    )
    
    process {

        # Define the certificate stores to search
        $stores = @('CurrentUser', 'LocalMachine') 
        foreach ($certStore in $stores) {

            # Get the certificate from the certificate store
            $result = Get-Item -Path "Cert:\$($certStore)\My\$($thumbprint)"
            if (-not $result) {
                Write-LogAndHost -Message ("Certificate with thumbprint '{0}' was not found in the '{1}' certificate store" -f $thumbprint, $certStore) -LogId $LogId -Severity 2

                return $false
            }
            else {
                Write-LogAndHost -Message ("Certificate with thumbprint '{0}' was found in the '{1}' certificate store with the subject '{2}'" -f $thumbprint, $certStore, $result.Subject) -LogId $LogId -ForegroundColor Green

                return $result
            }
        }
    }
}