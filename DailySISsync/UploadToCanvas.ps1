
#########################################################################################
# SETUP                                                                                 #
#########################################################################################

# Contains some utilities used here e.g. Write-Zip
Import-Module pscx

# Source directory containing input CSV files. 
$sourcePath = "C:\Canvas\SIS_Upload\Source"
# Output path for ZIP file creation.
$outputPath = "C:\Canvas\SIS_Upload\Destination"
$outputZip  = "canvas_import.zip"

$token = '<TOKEN>'
$headers = @{"Authorization"="Bearer "+$token}

$send_file   = "$outputPath\$outputZip" 

$dateTime = get-date -format yyyy.M.d_HHmm
$status_log_path = "$outputPath\$dateTime-status.log"


#########################################################################################
# Upload CSVs in ZIP format to Canvas.                                                  #
#########################################################################################


# Create a ZIP containing all the files to upload. 
Write-Zip -Path "$sourcePath\*.csv" -OutputPath $send_file | Out-Null

$upload_results = Invoke-WebRequest `
       -Headers $headers `
       -InFile $send_file `
       -Method POST `
       -ContentType 'application/zip'  `
	   -Uri 'https://<HOSTNAME>/api/v1/accounts/1/sis_imports.json?import_type=instructure_csv'
	   
$results = ($upload_results.Content | ConvertFrom-Json)
$upload_id = $results.id

Write-Output "Upload Information:" | Out-File $status_log_path
Write-Output "==========================================================================" | Out-File -Append $status_log_path
$results | Out-File -Append $status_log_path
Write-Output "==========================================================================" | Out-File -Append $status_log_path
Write-Output "`n`n" | Out-File -Append $status_log_path


#########################################################################################
# Poll the API for results of current upload until it is completed.                     #
#########################################################################################


Write-Output 'Polling API for results of upload at 60-second intervals.' | Out-File -Append $status_log_path

do {

       $status_result = Invoke-WebRequest `
              -Headers $headers `
              -Method GET `
			  -Uri "https://<HOSTNAME>/api/v1/accounts/1/sis_imports/$upload_id"
			  
       $status_result = $status_result.Content | ConvertFrom-Json
       Write-Output "$(Get-Date -Format hh:mm:ss) - $($status_result.Progress) percent completed." | Out-File -Append $status_log_path

       if ($status_result.progress -LT 100) {
              Start-Sleep -s 60
       }

} while ($status_result.progress -LT 100)

Write-Output "Final status: $($status_result.workflow_state).`n`n" | Out-File -Append $status_log_path


#########################################################################################
# Write any errors from this upload to the log.                                         #
#########################################################################################


# SIS import errors are returned in paginated form, so follow relation links to get full list. 
$errors_result = Invoke-RestMethod `
       -Headers $headers `
       -Method GET `
       -Uri "https://<HOSTNAME>/api/v1/accounts/1/sis_imports/$upload_id/errors" `
       -FollowRelLink

# This is a shortcut to get a list of all error objects from the last upload.
$error_list = $errors_result.sis_import_errors

Write-Output "$($error_list.items.count) errors for upload with ID $($upload_id):" | Out-File -Append $status_log_path
$error_list | Select-Object -Property Row,Message | Out-File -Append $status_log_path


#########################################################################################
# The sis import is done, you might do something else here like trigger course copies.  #
#########################################################################################


Move-Item -Force "$outputPath\$outputZip" "$outputPath\$dateTime-$outputZip"
Write-Output "`n`nFinished Canvas SIS import." | Out-File -Append $status_log_path
