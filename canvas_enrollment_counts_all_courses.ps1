
# Currently counts TA enrollments for each course in the main current terms. 

$termIds = @(
    1,  # Default Term
    22, # Semester_2_2020
    17, # Two_Year_2020_2021
    18, # Full_Year_2020
    19, # Semester_1_2020
    14, # Ongoing
    10  # Two_Year_2019_2020
)


#             ----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8----+----9
Write-Output "=========================================================================================="
Write-Output "COURSE                                                                        ID         N"
Write-Output "=========================================================================================="


foreach ($termId in $termIds) {

    # Get every course for this term. 

    # Initialise empty array to hold list of course objects. 
    $courses = @()

    $uriCourseList = "https://<HOSTNAME>/api/v1/accounts/1/courses?enrollment_term_id=$termId"

    $response = Invoke-RestMethod `
        -uri $uriCourseList `
        -method GET `
        -headers $headers `
        -FollowRelLink 

    foreach($page in $response) {
        $courses += $page
    }

    foreach($course in $courses) {
        # Get number of enrollments for each course. 
        
        $uriEnrollmentList = "https://<HOSTNAME>/api/v1/courses/$($course.id)/enrollments?type=TaEnrollment"

        $enrollments = Invoke-RestMethod `
            -uri $uriEnrollmentList `
            -method GET `
            -headers $headers `
            -FollowRelLink 

        if($enrollments.id.count -GT 0) {
            Write-Output $("{0,-70}{1,10}{2,10}" -f $course.name, $course.id, $enrollments.id.count)
        }
    }

}

