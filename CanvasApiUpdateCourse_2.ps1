
$token   = "<TOKEN>" 
$headers = @{"Authorization"="Bearer "+$token}
$uri     = "https://<HOSTNAME>:443/api/v1/courses/3807"

$body = @{
    'course[sis_course_id]'='SBPIANO_20_S1'
}

$response = Invoke-RestMethod `
	-URI $URI `
	-Headers $headers `
	-Method Put `
	-Body $body `
	-ContentType 'multipart/form-data'

Write-host $response