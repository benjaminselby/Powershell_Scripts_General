
$token   = "<TOKEN>" 
$headers = @{"Authorization"="Bearer "+$token}

# Parameters can be either included in the URL or added to the BODY of the request. 
# If they are added to the BODY, the ContentType='multipart/form-data' specifier must be 
# added to the web request. 
# $queryUrl = "https://<HOSTNAME>:443/api/v1/users/1034/enrollments?type[]=TaEnrollment&state[]=active"
$body = @{
	'type[]'='TaEnrollment'; 
	'state[]'='active'}

$queryUrl = "https://<HOSTNAME>:443/api/v1/users/1034/enrollments"

$queryObjects = @()

############################################################################################################

$queryResult = Invoke-RestMethod `
	-Headers $headers `
	-Method GET `
	-Uri "$queryUrl" `
	-Body $body `
	-ContentType 'multipart/form-data' `
	-FollowRelLink

# Because of pagination, queryResult will often contain a multidimensional array, with one
# element for each page. Each page in turn contains multiple objects, which are the results 
# of the query. It's simplest to add all objects to an array as follows. 

ForEach($object in $queryResult) {
	$queryObjects += $object
}

############################################################################################################

Write-Output "$($queryObjects.items.count) objects returned from query of URL: $queryUrl" 
$queryObjects #| Export-CSV './api_out.csv' -UseQuotes Never -Delim ","
