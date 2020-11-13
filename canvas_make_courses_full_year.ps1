
$token   = "<TOKEN>" 
$headers = @{"Authorization"="Bearer "+$token}

# Array of hashtable objects. 
$courses = 
    @{id=3234;  name='6KOPE Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='6KOPE_20_S1'},
    @{id=3237;  name='6MYPE Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='6MYPE_20_S1'},
    @{id=3187;  name='6KWPE Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='6KWPE_20_S1'},
    @{id=3197;  name='6TWPE Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='6TWPE_20_S1'},
    @{id=3275;  name='7PE1f Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='7PE1f_20_S1'},
    @{id=3271;  name='7PE1e Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='7PE1e_20_S1'},
    @{id=3277;  name='7PE1d Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='7PE1d_20_S1'},
    @{id=3273;  name='7PE1b Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='7PE1b_20_S1'},
    @{id=3269;  name='7PE1a Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='7PE1a_20_S1'},
    @{id=3374;  name='8GHPE Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='8GHPE_20_S1'},
    @{id=3292;  name='8AKPE Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='8AKPE_20_S1'},
    @{id=3321;  name='8DHPE Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='8DHPE_20_S1'},
    @{id=3371;  name='8STPE Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='8STPE_20_S1'},
    @{id=3413;  name='9RCPE Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='9RCPE_20_S1'},
    @{id=3430;  name='9ETPE Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='9ETPE_20_S1'},
    @{id=3376;  name='9JAPE Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='9JAPE_20_S1'},
    @{id=3441;  name='9SKPE Physical Education Sem 1';	    course_code='Physical Education S1';   sis_course_code='9SKPE_20_S1'},
    @{id=3574;  name='10PHE1D Physical Education Sem 1';	course_code='Physical Education S1';   sis_course_code='10PHE1D_20_S1'},
    @{id=3576;  name='10PHE1E Physical Education Sem 1';	course_code='Physical Education S1';   sis_course_code='10PHE1E_20_S1'},
    @{id=3571;  name='10PHE1B Physical Education Sem 1';	course_code='Physical Education S1';   sis_course_code='10PHE1B_20_S1'},
    @{id=3573;  name='10PHE1C Physical Education Sem 1';	course_code='Physical Education S1';   sis_course_code='10PHE1C_20_S1'},
    @{id=3578;  name='10PHE1F Physical Education Sem 1';	course_code='Physical Education S1';   sis_course_code='10PHE1F_20_S1'}


ForEach ($course in $courses) {

    Write-Host "Updating course: $($course.name)"

    $uri     = "https://<HOSTNAME>:443/api/v1/courses/$($course.id)"
    $body = @{
        "course[name]"          = "$($course.name.substring(0, $course.name.Length - 6))";
        "course[course_code]"   = "$($course.course_code.substring(0, $course.course_code.Length - 3))";
        "course[sis_course_id]" = "$($course.sis_course_code.substring(0, $course.sis_course_code.Length - 3))";
        "course[term_id]"       = "18"
    }

    Write-Host $uri
    $body 

    $response = Invoke-RestMethod `
    	-URI $URI `
        -Headers $headers `
        -Method PUT `
        -Body $body `
    	-ContentType 'multipart/form-data'

    Write-host $response

}