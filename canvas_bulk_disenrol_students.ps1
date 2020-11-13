
$token   = "<TOKEN>" 
$headers = @{"Authorization"="Bearer "+$token}

# These are enrollment IDs. Can get them from the Canvas Data database. 
$enrollments = 76313, 77240, 77239, 76310, 75419, 88434, 75390, 75407, 75414, 75417, 75655, 75695, 
    77241, 75691, 88314, 84855, 75668, 75410, 75413, 75721, 75727, 75736, 87928, 75684, 76320, 76323, 
    75382, 75401, 75394, 75398, 75404, 75367, 75371, 75375, 75644, 75649, 66035, 75942, 75959, 75961, 
    75964, 75968, 75675, 75680, 75687, 75699, 75702, 75706, 75711, 75741, 75334, 75349, 75352, 75363, 
    75379, 75386, 75661, 75730, 75733, 78835, 76340, 75337, 75340, 75343, 75346, 75358, 75360, 66038, 
    75934, 75951, 75716, 75355, 76306, 76316, 76326, 76329, 76343, 76333, 76336, 76347, 75926, 76350, 
    75724, 77445, 77446, 75930, 66041, 75939, 75946, 75955

foreach ($enrollment_id in $enrollments){
    $uri = "https://<HOSTNAME>:443/api/v1/courses/3433/enrollments/$($enrollment_id)?task=delete"
    Write-Host $uri

    $response = Invoke-RestMethod `
        -URI $URI `
        -Headers $headers `
        -Method DELETE

    $response
}