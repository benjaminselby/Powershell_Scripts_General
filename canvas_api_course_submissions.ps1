# This downloads all submission documents for all students in a Canvas course. 
# It can be modified to download only submissions for a particular student by adding that student's 
# ID value to the parameter 'student_ids[]=all' in the query url. 
# Currently handles submissions of two types - when a file has been uploaded, this file is 
# downloaded and saved with its original name (preceded by the submitter's canvas ID number). 
# A submission in 'online text' format will be saved to a file named with the submission datetime. 

$token   = "<TOKEN>" 
$headers = @{"Authorization"="Bearer "+$token}

$courseId = 3819 #3585

# Note use of the 'student_ids[]=all' parameter for this query. If that is missing, the query will only 
# return submissions for the calling user. 
$queryUrl = "https://<HOSTNAME>:443/api/v1/courses/$($courseId)/students/submissions?student_ids[]=all"

$queryObjects = @()

############################################################################################################

$queryResult = Invoke-RestMethod `
	-Headers $headers `
	-Method GET `
	-Uri "$queryUrl" `
	-FollowRelLink

# Because of pagination, $queryResult will often contain a multidimensional array, with one
# element for each page. Each page in turn contains multiple objects, which are the results 
# of the query. I have found it's most reliable to add all objects to an array before exporting to CSV. 

ForEach($pageObjects in $queryResult) {
	$queryObjects += $pageObjects
}

############################################################################################################

Write-Output "$($queryObjects.items.count) objects returned from query of URL: $queryUrl" 
$queryObjects | Export-CSV './api_out.csv' -UseQuotes Never -Delim ","

############################################################################################################

# Each submission object may have multiple attachments. Each attachment is an uploaded file. 
ForEach($submission in $queryObjects) {

	Write-Output "Submission for user id $($submission.user_id) for assignment $($submission.assignment_id) has $($submission.attachments.count) attachment(s)."

	if ($submission.attachments.count -EQ 0) { 
		if ($submission.submission_type -EQ 'online_text_entry') {
			Write-Output "Online text submission."
			Write-Output "`tPreview URL: $($submission.preview_url)"
			# Remove illegal characters from output file name. 
			$outFileName = "$($submission.user_id)_$($submission.submitted_at.toString().replace('/','.').replace(':','.').replace(' ', '_')).html"
			Write-Output "`tSaving to file: [$outFileName]"
			$submission.body | Out-File -FilePath "./$outFileName"
			Write-Output "`tDone.`n"
		} else {
			Write-Output "No submission body found.`n"
			Continue
		}
	}
	else {
		Write-Output "Attachments: ============================================"
		ForEach ($attachment in $submission.attachments) { 
			Write-Output "File name: [$($attachment.display_name)]"
			Write-Output "`tMIME type: $($attachment.'content-type')"
			Write-Output "`tDownload URL: $($attachment.url)"
		        Write-Output "`tSaving file..."
        		Invoke-Webrequest `
				-URI "$($attachment.url)"  `
				-OutFile "$($submission.user_id)_$($attachment.display_name)"
        		Write-Output "`tDone.`n"
		}
		Write-Output "========================================================="
	}
}	
