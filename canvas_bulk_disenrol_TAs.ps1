
$token   = "<TOKEN>" 
$headers = @{"Authorization"="Bearer "+$token}

$courseIds = 4006, 4233, 3106 # Can contain multiple ids: 3269, 3273, 3277, 3271, 3275


############################################################################################################################


foreach($courseId in $courseIds) {

    $response = Invoke-RestMethod `
        -URI "https://<HOSTNAME>:443/api/v1/courses/$($courseId)/enrollments?type[]=TaEnrollment" `
        -Headers $headers `
        -Method GET `
        -FollowRelLink

    # Because of pagination, $RESPONSE will often contain a multidimensional array, with one
    # element for each page. Each page in turn contains multiple objects, which are the results of the query. 
    # This is a shortcut to get an array of all enrollment IDs in the multidimensional array. 
    $enrollmentIds = $response.id

    # Should equal the number of TAs enrolled in the course. 
    Write-host "Got $($enrollmentIds.length) TA enrollments for course ID $courseId."

    foreach($enrollmentId in $enrollmentIds) {
        $uri = "https://<HOSTNAME>:443/api/v1/courses/$($courseId)/enrollments/$($enrollmentId)?task=delete"
        Write-Host $uri

        $response = Invoke-RestMethod `
            -URI $URI `
            -Headers $headers `
            -Method DELETE

        $response
    } 
}

