$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json
$success = $false
$auditLogs = [Collections.Generic.List[PSCustomObject]]::new()

#Change mapping here
$account = [PSCustomObject]@{ }

#region functions
# Write functions logic here

#endregion functions
$portalBaseUrl = $c.BaseUrl
$ApiToken = $c.ApiToken

if (-Not($dryRun -eq $true)) {
    # Write delete logic here
    try
    {
        $key = "Bearer $ApiToken"
        $headers = @{"X-Samanage-Authorization" = $Key}    

        $uri = ($PortalBaseUrl +"/users.json")
        $getpages = Invoke-WebRequest -Method GET -Uri $uri -Headers $headers
        $users = ($getpages.content | ConvertFrom-Json)
        $total = 0
        $totalstring = $getpages.headers.'x-total-pages'
        $total = $total + $totalstring[0]
        Write-Information ("Pages: " + $total)
        if ($total -ge 2)
        {
            for ($i = 2; $i -le $total; $i++)
            {
                $loopuri = $uri+"?page="+$i
                $correlationResponse = Invoke-RestMethod -Method GET -Uri $loopuri -Headers $headers
                $users += $correlationResponse
            }
        }
       
        $users = $users | where { $_.id -eq $aRef }
        Write-Information ("aref: " + $aRef)
        if (($users | Measure-Object).Count -ge 1)
        {
            $uri = ($PortalBaseUrl +"users/"+$aRef+".json")
            Write-Information $uri
            #Invoke-RestMethod -Method Delete -Uri $uri -Headers $headers | Out-Null
            $success = $true
            $auditLogs.Add([PSCustomObject]@{
                    # Action = "DeleteAccount" Optionally specify a different action for this audit log
                    Message = "Account $($aRef) deleted"
                    IsError = $false
                }
            )
        }
        else
        {
           $success = $true 
            $auditLogs.Add([PSCustomObject]@{
                    # Action = "DeleteAccount" Optionally specify a different action for this audit log
                    Message = "Account $($aRef) was already deleted"
                    IsError = $false
                }
            )
        }
    }catch{
        #User not found (expected case)
        $auditLogs.Add([PSCustomObject]@{
                # Action = "DeleteAccount" Optionally specify a different action for this audit log
                Message = "Account $($aRef) not deleted"
                IsError = $true
            }
        )
    }
}

# Send results
$result = [PSCustomObject]@{
    Success   = $success
    AuditLogs = $auditLogs
    Account   = $account
}

Write-Output $result | ConvertTo-Json -Depth 10