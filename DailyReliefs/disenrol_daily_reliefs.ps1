
$Token = '<TOKEN>'
$headers = @{Authorization="Bearer $token"}

$workingFolder = 'c:\canvas\daily_reliefs'
$dataFolder = "$workingFolder\data"
$logFilePath = "$workingFolder\Logs\"+$(get-date -format 'yyyy.MM.dd_hh.mm')+"_disenrol.log"


#########################################################################################
# FUNCTIONS
#########################################################################################


Function WriteLog([String] $message) {
    Write-Output $message | Out-File -Path $logFilePath -Append
}


#####################################################################################
# MAIN
#####################################################################################


WriteLog('Starting daily reliefs disenrollment upload.')

WriteLog('Exporting daily reliefs to be disenrolled into a CSV suitable for CANVAS SIS upload.')

$query	= @'
	select distinct
		CanvasCourseId as course_id,
		ReliefTeacherID as user_id,
		'TA' as role, 
		'' as section,
		'deleted' as status
	from dbo.DailyReliefs
	where DATEDIFF(Day, DateModified, GETDATE()) = 0
        and ReliefTeacherID <> ''
        and CanvasCourseId is not NULL
'@

$result	= Invoke-SQLcmd `
	-Query $query `
	-ServerInstance TESTSERVER2 `
	-Database CanvasAdmin

$result | export-csv "$dataFolder\enrollments.csv" -UseQuotes Never

WriteLog("`n`nDisenrollment upload file contains the following:")
WriteLog("============================================")
Get-Content -Path "$dataFolder\enrollments.csv" | ForEach-Object {WriteLog("$_")}
WriteLog("============================================`n`n")



#####################################################################################


if ($result.items.count -EQ 0) {
	WriteLog('No reliefs to disenrol for today. Canvas upload will be skipped. Finishing.')
	Return
}

WriteLog('Importing CSV into Canvas via API.')

$import_response = Invoke-WebRequest `
	-Uri "https://<HOSTNAME>/api/v1/accounts/1/sis_imports.json?import_type=instructure_csv" `
	-Headers $headers `
	-Method POST `
	-ContentType text/csv `
	-InFile "$dataFolder\enrollments.csv" 

$import_response = $import_response.Content | ConvertFrom-Json
$upload_id = $import_response.ID


#########################################################################################


WriteLog("`nPolling API for results of upload ID $upload_id at 30-second intervals.")

do {
	$status_url = "https://<HOSTNAME>/api/v1/accounts/1/sis_imports/$upload_id"
	$status_result = Invoke-WebRequest `
		-Headers $headers `
		-Method GET `
		-Uri $status_url 
	$status_result = $status_result.Content | ConvertFrom-Json

	WriteLog("$(Get-Date -Format 'hh:mm:ss')" + "$($status_result.Progress) percent completed.") 

	if ($status_result.progress -LT 100) {
		Start-Sleep -s 30
	}

} while ($status_result.progress -LT 100)

WriteLog("Final status: $($status_result.workflow_state).`n`n") 


#########################################################################################
# Write any errors from this upload to the log. 
#########################################################################################


# SIS import errors are returned in paginated form, so follow relation links to get full list. 
$errorsResult = Invoke-RestMethod `
	-Headers $headers `
	-Method GET `
	-Uri "https://<HOSTNAME>/api/v1/accounts/1/sis_imports/$upload_id/errors" `
	-FollowRelLink

# Response object contains an array called SIS_IMPORT_ERRORS, which contains 
# all errors from the last upload as objects. 
$errorList = $errorsResult.sis_import_errors

WriteLog("$($errorList.items.count) errors for upload with ID $($upload_id):") 
$errorList | ForEach-Object {WriteLog("Row: $($_.row) - $($_.message)")}

WriteLog("`nDone.")
