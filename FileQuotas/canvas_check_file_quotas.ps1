

$DebugPreference = 'continue'


#########################################################################################################
# VARIABLES
#########################################################################################################


$token = '<TOKEN>'
$headers    = @{Authorization="Bearer $token"}

$rootFolder     = 'C:\Canvas\FileQuotas'
$logFilePath    = "$rootFolder\Logs\FileQuotas_$(get-date -format 'yyyy.MM.dd_hh.mm').log"

# Array to store info for all users who have exceeded file quotas. 
$badUsers = @()


#########################################################################################################
# FUNCTIONS
#########################################################################################################


Function GetPersonalFiles {

    # Returns a list of user (ie. personal) files. Also attaches some folder information. 
    # Note that user files are those not associated with course submissions. 
    # Currently users are allowed only 50MB of space for personal files. 

    PARAM (
        [Parameter(Mandatory=$true)] $userCanvasId
    )
    
    # Array which will contain a set of all the user's personal files (ie. not assignment submissions.)
    $personalFiles = @()

    #########################################################################################################

    # Get list of all files owned by the user. 
    $filesResponse = Invoke-RestMethod `
        -uri "https://<HOSTNAME>:443/api/v1/users/$userCanvasId/files?as_user_id=$userCanvasId" `
        -Method GET `
        -Headers $headers `
        -FollowRelLink

    $allFiles = $filesResponse | ForEach-Object {$_}

    # Extract all personal files. Personal files are stored in folders which are marked as not for submissions. 
    foreach ($file in $allFiles) {

        try {

            # This request should only return a single object. 
            $folderRequestUri = "https://<HOSTNAME>:443/api/v1/users/$userCanvasId/folders/$($file.folder_id)?as_user_id=$userCanvasId"
            $folder = Invoke-RestMethod `
                -uri $folderRequestUri `
                -Method GET `
                -Headers $headers `
                -FollowRelLink

        } catch {
            Write-Output "ERROR: There was a problem with the GET folder REST request for URI: $folderRequestUri"
            Write-Output "MESSAGE: $($_.ErrorDetails.Message)"
            Return
        }

        if ($folder.for_submissions -NE $true) {
            $personalFiles += @{
                id          = $file.id
                name        = $file.display_name
                size        = $file.size
                created     = $file.created_at
                updated     = $file.updated_at
                folderId    = $file.folder_id
                folderPath  = $folder.full_name
            }
        }
    }

    return $personalFiles
}


Function CheckFileQuota {

    Param(
        [Parameter(Mandatory=$true)] $userCanvasId,
        $nFilesToReturn         = 10
    )
    
    try {
        $getUserInfoUri = "https://<HOSTNAME>:443/api/v1/users/$userCanvasId"
        $user = Invoke-RestMethod `
            -Uri  $getUserInfoUri `
            -Method GET `
            -Headers $headers `
            -FollowRelLink
    } catch {
        Write-Output "ERROR: Unable to get user information from URI: $getUserInfoUri"
        Write-Output "MESSAGE: $($_.ErrorDetails.Message)"
        Return
    }

    #########################################################################################################

    try {
        $quotaRequestUri = "https://<HOSTNAME>:443/api/v1/users/$userCanvasId/files/quota?as_user_id=$userCanvasId"
        $quotaResponse = Invoke-RestMethod `
            -uri $quotaRequestUri `
            -Method GET `
            -headers $headers `
            -FollowRelLink
    } catch {
        Write-Output "ERROR: Unable to get file quota for user $userCanvasId from URI: $quotaRequestUri"
        Write-Output "MESSAGE: $($_.ErrorDetails.Message)"
        Return
    }
        
    #########################################################################################################

    if ($quotaResponse.quota_used -GE $quotaResponse.quota) {
        
        $badUsers += @{
            name        = "$user.name"
            canvasId    = "$user.id" 
            synergyId   = "$user.sis_user_id"
            email       = "$user.email"
        }

        Write-Output "`n$($user.name) [CANVAS ID: $($user.id) SYNERGY ID: $($user.sis_user_id) EMAIL: $($user.email)] has exceeded file quota."
        Write-Output ("    QUOTA: {0,15:n0}" -f $quotaResponse.quota)
        Write-Output ("    USED:  {0,15:n0}" -f $quotaResponse.quota_used)

        $userFiles = GetPersonalFiles -userCanvasId $userCanvasId 

        $topFiles = $userFiles | Sort-Object size -Descending | Select-Object -First $nFilesToReturn

        #          ----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8----+----9----+----0----+----1----+----2----+----3
        Write-Output "Largest $nFilesToReturn files:"
        Write-Output "=================================================================================================================================="
        Write-Output "        SIZE |       ID | LAST MODIFIED | PATH"
        Write-Output "=================================================================================================================================="
        foreach ($file in $topFiles) {
            Write-Output ('{0,12:n0} | {1,8} | {2,13} | {3,-85}' -f 
                $file.size, 
                $file.id, 
                $file.updated.ToString('yyyy.MM.dd'), 
                ($file.folderPath + '/' + $file.name))
        }
        Write-Output "=================================================================================================================================="

        # TODO: Email user about file quota violation? 

    }
}


#########################################################################################################
# MAIN
#########################################################################################################


$usersResponse = Invoke-RestMethod `
    -URI "https://<HOSTNAME>:443/api/v1/accounts/1/users" `
    -headers $headers `
    -method GET `
    -FollowRelLink

$currentUsers = $usersResponse | Foreach-Object {$_}

foreach($user in $currentUsers) {
    CheckFileQuota -userCanvasId $user.id *>&1 | Out-File -Path $logFilePath -Append
}

Write-Output "$($badUsers.count) users have exceeded their file quotas." *>&1 | Out-File -Path $logFilePath -Append

