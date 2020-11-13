
# This script reports all enrollments (of a particular type) for all courses within 
# a specified set of enrollment terms. 


##################################################################################################################
# VARIABLES
##################################################################################################################


$token = '<TOKEN>'
$headers    = @{Authorization="Bearer $token"}


# Only courses in these terms will be scanned. 
$termIds = @(
    1,  # Default Term
    22, # Semester_2_2020
    17, # Two_Year_2020_2021
    18, # Full_Year_2020
    # 19, # Semester_1_2020
    14, # Ongoing
    10  # Two_Year_2019_2020
)

# Set this to empty string to get all enrollments.
$enrollmentType = "ObserverEnrollment"

# Array which will hold a list of all the target enrollments across all courses. 
$allEnrollments = @()


##################################################################################################################
# MAIN
##################################################################################################################


#             ----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8----+----9
Write-Output ("`n`nEnrollments by course where enrollment type = [{0}]." -f (&{if($enrollmentType.Trim() -EQ '') { 'All' } else { $enrollmentType }}))
Write-Output "=========================================================================================="
Write-Output "COURSE NAME                                                     COURSE CANVAS ID         N"
Write-Output "=========================================================================================="


foreach ($termId in $termIds) {

    # Get every course for this term. 

    # Initialise empty array to hold list of course objects for this term. 
    $termCourses = @()

    $uriCourseList = "https://<HOSTNAME>/api/v1/accounts/1/courses?enrollment_term_id=$termId"

    $response = Invoke-RestMethod `
        -uri $uriCourseList `
        -method GET `
        -headers $headers `
        -FollowRelLink 

    foreach($page in $response) {
        $termCourses += $page
    }

    foreach($course in $termCourses) {

        $enrollments = @()
        
        $uriEnrollmentList = "https://<HOSTNAME>/api/v1/courses/$($course.id)/enrollments?type=$enrollmentType"

        $response = Invoke-RestMethod `
            -uri $uriEnrollmentList `
            -method GET `
            -headers $headers `
            -FollowRelLink 

        # The REST response may be paginated. This puts all elements into a single array. 
        $enrollments = $response | ForEach-Object {$_}
        
        if($enrollments.count -GT 0) {
            # Todo - save this report line to a file and output as CSV once complete pass has been made.
            Write-Output $("{0,-70}{1,10}{2,10}" -f $course.name, $course.id, $enrollments.id.count)            
            $allEnrollments += $enrollments
        }
    }

}

Write-Output "`n`n"
Write-Output "Exporting enrollments to data file..."
$allEnrollments `
    | Select-Object id, user_id, course_id, type, created_at, associated_user_id, course_section_id, `
                root_account_id, enrollment_state, role, role_id, last_activity_at, `
                {$_.user.name}, {$_.user.sis_user_id}, {$_.user.login_id} `
    | Export-Csv -path "./$($enrollmentType.Trim())_Enrollments.csv" -delim ',' -UseQuotes Never
Write-Output "Finished."

