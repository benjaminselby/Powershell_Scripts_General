
$token   = "<TOKEN>" 
$headers = @{"Authorization"="Bearer "+$token}

$usersQueryUrl = "https://<HOSTNAME>:443/api/v1/accounts/1/users"

$userObjects = New-Object System.Collections.ArrayList @()
$observeeObjects = New-Object System.Collections.ArrayList @()

$outputDataTable = New-Object System.data.DataTable
[void]$outputDataTable.Columns.Add('UserCanvasId') 
[void]$outputDataTable.Columns.Add('ObserveeCanvasId') 

$ERROR_CODE = 9

########################################################################################################

Function LoadContentObjectsArray([string] $Url, [System.Collections.ArrayList] $arrayList) {
	$pageNumber = 1
	do {

		# Get a single page of data from the Canvas API.
		$resultsPage = Invoke-WebRequest `
			-Method GET `
			-Headers $headers `
			-Uri "$($Url)?per_page=100&page=$pageNumber"

		# Bug out early if no results are returned. 
		if ($resultsPage -EQ $NULL) {
			return $ERROR_CODE
		}

		$contentPage = ConvertFrom-Json $resultsPage.Content

		Write-Host "Found $($contentPage.count) objects."
		Write-Host $contentPage

		# Append each content object in the results page to the ArrayList.
		foreach ($contentObject in $contentPage) {	
			$arrayList.Add($contentObject) 
		}
	
		$pageNumber++

	# Do until the RelationLink list does not contain an object with KEY='Next'. This indicates
	# that the current page is the last one in a pagination sequence. 
	} while ($resultsPage.RelationLink.Next -NE $NULL)
} 

########################################################################################################



if(LoadContentObjectsArray $usersQueryUrl $userObjects -EQ $ERROR_CODE){
	Write-Host 'Error loading object ArrayList from API.'
}

Write-Host $userObjects.count user objects returned. 

# Get the observees for every user, if any exist. 
foreach ($user in $userObjects) {

	$userCanvasId = $user.id
	$observeeQueryUrl = "https://<HOSTNAME>:443/api/v1/users/$($userCanvasId)/observees"
	$observeeObjects = @()
	
	Write-host Loading observees from URL: $observeeQueryUrl
	LoadContentObjectsArray $observeeQueryUrl $observeeObjects

	Write-Host "Found $($observeeObjects.Count) observees for this user."
	Write-Host "ObserveeObjects:"
	Write-Host $observeeObjects

	# If any observees are found for this user, add them to a data table. 
	foreach($observee in $observeeObjects){
		Write-Host "Iterating over observee objects for this user." 
		$outputDataTable.rows.add(
			$userCanvasId,
			$observee.Id
		)
	}
}

$outputDataTable | Export-CSV -Path 'outputDataTable.csv' -usequotes never

