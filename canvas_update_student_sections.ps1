
$token   = "<TOKEN>" 
$headers = @{"Authorization"="Bearer "+$token}

##############################################################################################################

$courseId = 3301

# Synergy IDs of students who will be assigned a new section. 
$students = '33417', '19910', '29861', '23126', '34223', '34267', '34444', '21231', '33200', '32851', '30743', 
    '26055', '32670', '36065', '36426', '36008', '25821', '21861', '35082', '24629', '30173', '28584', '33986', '34811', '33426'

$newSectionId = 3377

##############################################################################################################

# Get a list of all student enrollments for the course. 
$response = Invoke-RestMethod `
    -URI "https://<HOSTNAME>:443/api/v1/courses/$courseId/enrollments?type[]=StudentEnrollment" `
    -Headers $headers `
    -Method GET `
    -FollowRelLink

# Because of pagination, $RESPONSE will often contain a multidimensional array, with one
# element for each page. Each page in turn contains multiple objects, which are the results of the query. 
# This is a shortcut to get an array of all enrollment objects in the multidimensional array. 
$enrollments = $response | ForEach-Object {$_}

Write-host "Got $($enrollments.length) student enrollments for course ID $courseId."

# Note that if a student has been enrolled incorrectly in two sections, this will result in TWO enrollments. 
# Both will be deleted here, and the student will be re-enrolled twice (into the correct section). 
# Enrolling the student twice here is not a problem because it will only result in a single final enrollment. 
foreach($enrollment in $enrollments){
    if ($students.Contains($enrollment.sis_user_id)) {
        
        Write-Host "Student with SIS id $($enrollment.sis_user_id) will be updated to new section $newSectionId."

        # First delete the existing enrollment for the student. 
        $response = Invoke-RestMethod `
            -URI "https://<HOSTNAME>:443/api/v1/courses/$courseId/enrollments/$($enrollment.id)?task=delete" `
            -Headers $headers `
            -Method DELETE
            
        # Now re-enrol the student to the required section. 

        $uri = "https://<HOSTNAME>:443/api/v1/sections/$newSectionId/enrollments?" `
            + "enrollment[user_id]=$($enrollment.user_id)" `
            + "&enrollment[course_section_id]=$newSectionId" `
            + "&enrollment[enrollment_state]=active"

        $response = Invoke-RestMethod `
            -URI $uri `
            -Headers $headers `
            -Method POST
    }
}

