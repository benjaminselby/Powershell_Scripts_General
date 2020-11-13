
# selby_b 2020.10.13 - This script is used to detect avatar images which have been uploaded by
# our system in the past, but which do not have a valid content-type/MIME class value. 
# If an image does not have the correct content-type/MIME class value, it cannot be assigned 
# as an avatar image. 
# This seemed to happen randomly in the past for image file uploads when I was using Powershell's 
# Invoke-RestMethod to send the file data. I have recently modified the image sync script to use 
# the CURL utility to send the image file data. This seems to have fixed the problem (so far...)


Param (
    [string] $deleteBadImages   = 'N',
    [string] $rootFolder        = (Split-Path $MyInvocation.MyCommand.path),
    [string] $logFilePath       = "$rootFolder\Logs\FindBadAvatarImages_$(get-date -format 'yyyy.MM.dd_hh.mm').log",
    [string] $token             = '<TOKEN>'
)


# Authentication header for API calls. 
$headers    = @{Authorization="Bearer $token"}


#########################################################################################################
# MAIN
#########################################################################################################


Write-Output "Started at $(Get-Date -Format 'HH:mm:ss')`n" 

$usersResponse = Invoke-RestMethod `
    -URI "https://<HOSTNAME>:443/api/v1/accounts/1/users" `
    -headers $headers `
    -method GET `
    -FollowRelLink

# Remove pagination from response array. 
$currentUsers = $usersResponse | Foreach-Object {$_}

foreach($user in $currentUsers) {
    # Only process users who have a valid numeric Synergy ID. This should filter out most parent observers etc. 
    if ($user.sis_user_id -MATCH '^\d+$') {
        Write-Output "========================================================================================" `
        Write-output "Checking avatar image for $($user.name) [CID: $($user.id) SID: $($user.sis_user_id)]"

        # Get the user's PROFILE PICTURES folder. 

        $folders = Invoke-RestMethod `
            -uri "https://<HOSTNAME>:443/api/v1/users/$($user.id)/folders" `
            -method GET `
            -headers $headers `
            -FollowRelLink

        # We need to use ForEach-Object to read objects because of pagination in the REST response. 
        $profilePicturesFolder = $folders | ForEach-Object {$_} | Where-Object {$_.Name.ToLower() -EQ 'profile pictures'}

        if($profilePicturesFolder -EQ $nothing) {
            Write-output "Could not find any PROFILE PICTURES folder for this user. Exiting."
            Continue
        }

        $files =  Invoke-RestMethod `
            -uri "https://<HOSTNAME>:443/api/v1/folders/$($profilePicturesFolder.id)/files" `
            -method GET `
            -headers $headers `
            -FollowRelLink

        Write-Output "Found the following files in PROFILE PICTURES folder:"
        $files | Select-Object id, filename, display_name, content-type, mime_class | format-table
        
        # Determine if the current Synergy image has an incorrect MIME type. 
        
        $synergyImage = $files | ForEach-Object {$_} | Where-Object {$_.filename -MATCH "$($user.sis_user_id).jpg"}
        
        if($synergyImage -EQ $nothing) {
            Write-output "No image matching Synergy ID $($user.sis_user_id) was found in this users' PROFILE PICTURES folder. Exiting."
            Continue
        }
        
        if($synergyImage.'content-type' -NE 'image/jpeg') {

            Write-Output "WARNING: Synergy image does not have the correct CONTENT-TYPE."
            $synergyImage | Select-Object id, filename, display_name, content-type, mime_class | format-table

            if ($deleteBadImages -EQ 'Y') {
                
                $deleteResponse =  Invoke-RestMethod `
                    -uri "https://<HOSTNAME>:443/api/v1/files/$($synergyImage.id)?as_user_id=$($user.id)" `
                    -method DELETE `
                    -headers $headers `
                    -FollowRelLink

                # Not sure how to check for success of DELETE here... Delete response seems to just contain file info.

                Write-Output "Deleted Synergy image for this user."
            }
        }
    }
}

Write-Output "`nFinished at $(Get-Date -Format 'HH:mm:ss')." 
