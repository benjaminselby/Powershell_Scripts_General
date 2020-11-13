
Param(
    [Parameter(Mandatory=$true)] 
    [string] $fileId,
    [string] $token             = '<TOKEN>'
)

$headers    = @{Authorization="Bearer $token"}

$fileResponse = Invoke-RestMethod `
    -Uri "https://<HOSTNAME>:443/api/v1/files/$fileId" `
    -Headers $headers `
    -Method Get

$fileDownloadUrl = $fileResponse.url
$fileName = $fileResponse.display_name

curl $fileDownloadUrl -o "$fileName" -L
