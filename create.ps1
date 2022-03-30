$config = ConvertFrom-Json $configuration

$portalBaseUrl = $config.BaseUrl
$ApiToken = $config.ApiToken

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

#Initialize default properties
$success = $False;
$p = $person | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$auditMessage = "Account for person " + $p.DisplayName + " not created succesfully";

#Change mapping here

$account = [PSCustomObject]@{
    name            = $p.Name.NickName + " " + $p.Name.FamilyName;
    title                = $p.primaryContract.Title.Name
    email         = $p.Contact.Business.Email;
    phone                = $p.Contact.Business.Phone.Fixed;
    mobile_phone          = $p.Contact.Business.Phone.Mobile;
    department            = [PSCustomObject]@{
        name = $p.primaryContract.Department.DisplayName;
    }
}


#Create or Correlate
try{
    Write-Information "try"

    if(-Not($dryRun -eq $True)) {
        # Create authorization headers with HelloID API key
        $key = "Bearer $ApiToken"

        $headers = @{"X-Samanage-Authorization" = $Key}

        # Define specific endpoint URI
        if($PortalBaseUrl.EndsWith("/") -eq $false){
            $PortalBaseUrl = $PortalBaseUrl + "/"
        }
        #$uri = ($PortalBaseUrl +"api/v1/users")
        $uri = ($PortalBaseUrl +"users.json")

        #Append desired username to portal uri
        $correlationUri = $uri
        
        #Look for account by username
        $getpages = Invoke-WebRequest -Method GET -Uri $correlationUri -Headers $headers
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
       
        $users = $users | where { $_.email -eq $account.Email }
        
        if (($users | Measure-Object).Count -ge 1)
        {
            #Correlate User
            $aRef = $users.id
            $success = $True;
            $auditMessage = " $($p.DisplayName) found and correlated successfully"
        }
        else
        {
            $body = $account | ConvertTo-Json -Depth 10
            #Create the user account
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ContentType "application/json" -Verbose:$false
            #Return the GUID for accountReference
            $aRef = $response.id

            $success = $True;
            $auditMessage = " created succesfully"; 
        }
    }
}catch{
    Write-Information "catch"
    #User not found (expected case)
    $auditMessage = " not created succesfully: $_"; 
}

#build up result
$result = [PSCustomObject]@{ 
	Success = $success;
	AccountReference = $aRef;
	AuditDetails = $auditMessage;
    Account = $account;
};

#send result back
Write-Output $result | ConvertTo-Json -Depth 10