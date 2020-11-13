
# This disenrolls a student from a sub-set of their Canvas courses. It is currently
# set to disenroll Y11 students from all IB courses, which is useful when students
# leave the IB program. 

# Make all errors terminating
$ErrorActionPreference = "Stop" 

################################################################################
# GLOBAL VARIABLES 
################################################################################

$token   = "<TOKEN>" 
$headers = @{"Authorization"="Bearer "+$token}

$userId = 2478

$allEnrollments = @()
$enrollmentsToRemove = @()

################################################################################
# GET ALL ENROLLMENTS FOR STUDENT 
################################################################################

# Get an array of enrollment objects for this user. 
$response = Invoke-RestMethod `
    -URI "https://<HOSTNAME>:443/api/v1/users/$userId/enrollments?type=StudentEnrollment" `
    -headers $headers `
    -method GET `
    -FollowRelLink

foreach($page in $response){
    $allEnrollments += $page
}

Write-Host "$($allEnrollments.count) enrollments found for user with ID $userId."

################################################################################
# GET LIST OF ENROLLMENTS TO REMOVE BASED ON MATCH CONDITION 
################################################################################

foreach($enrollment in $allEnrollments) { 

    # Get course name for this enrollment. 
    $course = Invoke-RestMethod `
        -URI "https://<HOSTNAME>:443/api/v1/courses/$($enrollment.course_id)" `
        -headers $headers `
        -method GET 

    # Write-Host "$($course.id) - $($course.Name)"

    # This currently filters for only Y11 IB courses. Useful when students drop out of the IB program. 
    if ($course.name -match '^.*11.*IB.*$') {
        $enrollmentsToRemove += @{Id = $enrollment.id; CourseName = $course.name; CourseId = $course.id}
    }
}

################################################################################
# CONFIRM WITH USER 
################################################################################

Write-Host "The following enrollments will be removed:"
$enrollmentsToRemove | Select-Object CourseId, CourseName | Format-List
do {
    $k = Read-Host "OK to proceed? (Y/N)"
} until ($k -match 'Y|N' -and $k.length -EQ 1)

if ($k -EQ 'N') {
    Write-Host "Aborted action. Exiting"
    Return
}

################################################################################
# REMOVE ENROLLMENTS 
################################################################################

foreach($enrollment in $enrollmentsToRemove) {

    $course = Invoke-RestMethod `
        -URI "https://<HOSTNAME>:443/api/v1/courses/$($enrollment.courseId)/enrollments/$($enrollment.id)" `
        -headers $headers `
        -method DELETE

    Write-Host "Removed enrollment #$($enrollment.id) for course #$($enrollment.courseId) - $($enrollment.courseName)."
}

Write-Host "Finished."
