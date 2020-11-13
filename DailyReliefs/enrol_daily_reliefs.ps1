
param (
	# If set to Y, this script will exit if the input XML file has not been modified 
	# since last run-time (ie. it will not run unnecessarily).
	[string] $checkInputFileModified = 'Y',
	# If set to Y, output messages will be written to the log file instead of the console.
	[string] $writeToLog        = 'Y'
)

$token = '<TOKEN>'
$headers    = @{Authorization="Bearer $token"}

$rootFolder     = "$(Split-Path $MyInvocation.MyCommand.path)"
$workingFolder  = "$rootFolder\Data"
$initFilePath   = "$rootFolder\enrol_init.json"
$logFilePath    = "$rootFolder\Logs\"+$(get-date -format 'yyyy.MM.dd_hh.mm')+"_enrol.log"

$inputFilePath  = "\\<PATH>\$(Get-Date -Format 'yyMMdd')_Daily Organiser $(Get-Date -Format 'yyyy').pdof9"

#########################################################################################
# FUNCTIONS
#########################################################################################


Function WriteLog([String] $message) {
	if ($writeToLog -EQ 'Y') {
		Write-Output $message | Out-File -Path $logFilePath -Append
	} else {
		Write-Host $message 
	}
}


#########################################################################################
# INIT
#########################################################################################


WriteLog("Starting daily reliefs enrollment upload process.")


if ($(Test-Path $inputFilePath) -NE 'True') {
	WriteLog("No daily reliefs file found at:") 
	WriteLog("$inputFilePath")
	WriteLog("Exiting.")
	Return
} 

WriteLog("Reading from DailyOrganiser file at:`n$inputFilePath")


if ($(Test-Path $initFilePath) -NE 'True') {
	WriteLog "No INIT file found at:"
	WriteLog("$initFilePath")
	WriteLog("Exiting.")
	Return
}

# Check if the DailyOrganiser file has been modified since our last run time. 
# Read input file modification date at last run time from INIT file. 
if ($checkInputFileModified -EQ 'Y') {
	$lastLoadDateTime = $(Get-Content "$initFilePath" | ConvertFrom-Json).DateModified
	$inputFileLastModifiedDateTime = $(Get-Item "$inputFilePath").LastWriteTime.ToString('yyyy/MM/dd hh:mm:ss')
	WriteLog("Input file modification time at last load: $lastLoadDateTime")
	WriteLog("Input file current modification time: $inputFileLastModifiedDateTime")
	if ( $lastLoadDateTime -GE $inputFileLastModifiedDateTime ) {
		WriteLog("DailyOrganiser file HAS NOT been modified since last data load. No need to execute. Exiting.")
		Return
	}
}

# Save current input file modification date to the INIT file in JSON format. 
$initObj = @{
	'DateModified' = "$($(Get-Item $inputFilePath).LastWriteTime.ToString('yyyy/MM/dd hh:mm:ss'))"
} 
$initObj | ConvertTo-JSON > $initFilePath


#########################################################################################
# BEGIN MAIN
#########################################################################################


WriteLog('Loading daily reliefs data from DailyOrganiser XML file into database.')

Invoke-Sqlcmd `
	-Query "EXEC dbo.spLoadDailyReliefs @inputXmlFilePath='$inputFilePath'" `
	-ServerInstance TESTSERVER2 `
	-Database CanvasAdmin


#########################################################################################


WriteLog('Querying database into a CSV suitable for CANVAS SIS upload.')

$query = @'
	select distinct
		CanvasCourseId as course_id,
		ReliefTeacherID as user_id,
		'TA' as role, 
		'' as section,
		'active' as status
	from dbo.DailyReliefs
	where DATEDIFF(Day, DateModified, GETDATE()) = 0
        and ReliefTeacherID <> ''
        and CanvasCourseId is not NULL
'@

$result	= Invoke-SQLcmd `
	-Query $query `
	-ServerInstance TESTSERVER2 `
	-Database CanvasAdmin


$result | export-csv "$($workingFolder)\enrollments.csv" -UseQuotes Never

WriteLog("`n`nEnrollment upload file contains the following:")
WriteLog("============================================")
Get-Content -Path "$workingFolder\enrollments.csv" | ForEach-Object {WriteLog("$_")}
WriteLog("============================================`n`n")


#########################################################################################


if ($result.items.count -EQ 0) {
	WriteLog('No reliefs loaded from input file. Upload to Canvas will be skipped. Finishing.')
	Return
}

WriteLog('Importing enrollments CSV into Canvas via API.')
	
$import_response = Invoke-WebRequest `
	-Uri "https://<HOSTNAME>/api/v1/accounts/1/sis_imports.json?import_type=instructure_csv" `
	-Headers $headers `
	-Method POST `
	-ContentType text/csv `
	-InFile "$($workingFolder)\enrollments.csv" 
	
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

	WriteLog("$(Get-Date -Format hh:mm:ss) - $($status_result.Progress) percent completed.")

	if ($status_result.progress -LT 100) {
		Start-Sleep -s 30
	}

} while ($status_result.progress -LT 100) 

WriteLog("Final status: $($status_result.workflow_state).`n") 


#########################################################################################
# Write any errors from this Canvas SIS upload to the log.                              #
#########################################################################################


# SIS import errors are returned in paginated form, so follow relation links to get full list. 
$errors_result = Invoke-RestMethod `
	-Headers $headers `
	-Method GET `
	-Uri "https://<HOSTNAME>/api/v1/accounts/1/sis_imports/$upload_id/errors" `
	-FollowRelLink

# Response object contains an array called SIS_IMPORT_ERRORS, which contains 
# all errors from the last upload as objects. 
$error_list = $errors_result.sis_import_errors

WriteLog("$($error_list.items.count) errors for upload with ID $($upload_id):")
$error_list | ForEach-Object {WriteLog("Row: $($_.row) - $($_.message)")}


#########################################################################################
# Send any necessary notification emails for Student Services information.              #
#########################################################################################

WriteLog("`n====================== STUDENT SERVICES INFORMATION EMAIL NOTIFICATIONS ======================")

# Need to use Invoke-Expression here so we can include the root folder in the script invocation.
$command = "$rootFolder\email_daily_relief_notifications.ps1 | Out-File -FilePath '$logFilePath' -Append"
Invoke-Expression $command

WriteLog("`nDone.")
