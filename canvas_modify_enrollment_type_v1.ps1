
$token   = "<TOKEN>" 
$headers = @{"Authorization"="Bearer "+$token}

##############################################################################################################

$courseId = 3830

# These values must match those strings expected by the Canvas API. 
$currentEnrollmentType  = "TeacherEnrollment"
$newEnrollmentType      = "StudentEnrollment"

$currentEnrollments = @()

##############################################################################################################

# Get a list of all enrollments of the specified type for this course. 
$enrollmentsResponse = Invoke-RestMethod `
    -URI "https://<HOSTNAME>:443/api/v1/courses/$courseId/enrollments?type[]=$currentEnrollmentType" `
    -Headers $headers `
    -Method GET `
    -FollowRelLink

# This is a shortcut to get an array of all enrollment objects in the paginated REST method response.  
$currentEnrollments = $enrollmentsResponse | Foreach-Object {$_}

Write-host "Got $($currentEnrollments.length) enrollments of type '$currentEnrollmentType' from course $courseId."

##############################################################################################################

foreach($enrollment in $currentEnrollments){

    Write-Host "Enrollment for user with SIS id $($enrollment.sis_user_id) will be updated to new enrollment type $newEnrollmentType."

    # First delete the existing enrollment for the user. 
    $deleteResponse = Invoke-RestMethod `
        -URI "https://<HOSTNAME>:443/api/v1/courses/$courseId/enrollments/$($enrollment.id)?task=delete" `
        -Headers $headers `
        -Method DELETE
            
    # Now re-enrol the user as a different enrollment type. 

    $uri = "https://<HOSTNAME>:443/api/v1/courses/$courseId/enrollments?" `
        + "enrollment[user_id]=$($enrollment.user_id)" `
        + "&enrollment[type]=$newEnrollmentType" `
        + "&enrollment[enrollment_state]=active"

    $enrollResponse = Invoke-RestMethod `
        -URI $uri `
        -Headers $headers `
        -Method POST
}
