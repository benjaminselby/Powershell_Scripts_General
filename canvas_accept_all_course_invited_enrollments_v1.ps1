
$token      = '<TOKEN>'
$headers    = @{Authorization="Bearer $token"}

# All pending 'invited' enrollments for this course will be accepted. 
$courseId = 3830

# Get all enrollments in 'Invited' state. 
 $response = Invoke-RestMethod `
    -Uri "https://<HOSTNAME>:443/api/v1/courses/$courseId/enrollments?state[]=invited" `
    -Method GET `
    -Headers $headers `
    -FollowRelLink

$enrollmentsInvitedPending = $response | ForEach-Object {$_}

Write-Output "Got $($enrollmentsInvitedPending.count) invitations pending for course $courseId."
Write-Output "OK to proceed?"
Write-Output "(Press Y to continue, any other key to exit.)"

$KeyPress = [System.Console]::ReadKey($True)
if ($KeyPress.KeyChar -NE 'y') {
    Write-Output "User chose to exit program. No enrollments processed."
    Return
} else {
    Write-Output "OK, processing enrollments."
}

foreach($enrollment in $enrollmentsInvitedPending){
    $response = Invoke-RestMethod `
        -Uri "https://<HOSTNAME>:443/api/v1/courses/$($enrollment.course_id)/enrollments/$($enrollment.id)/accept?as_user_id=$($enrollment.user_id)" `
        -Method POST `
        -Headers $headers `
        -FollowRelLink
    
    if($response.success -NE $True) {
        Write-Output "ERROR ACCEPTING ENROLLMENT $($enrollment.id) for user $($enrollment.user_id) for course $($enrollment.course_id)"
    } else {
        Write-Output "OK - Accepted enrollment $($enrollment.id) for user $($enrollment.user_id) for course $($enrollment.course_id)"
    }
}