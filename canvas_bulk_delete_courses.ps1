
$token   = "<TOKEN>" 
$headers = @{"Authorization"="Bearer "+$token}

# These are the courses to delete. 
$courses =     
    @{id=3788; name='ACDRUMS Drums Sem 1';              sis_course_code='ACDRUMS_20_S1'},
    @{id=3789; name='AGVOICE Voice Sem 1';              sis_course_code='AGVOICE_20_S1'},
    @{id=3790; name='ALGUITAR Guitar Sem 1';            sis_course_code='ALGUITAR_20_S1'},
    @{id=3793; name='GWVOICE Voice Sem 1';              sis_course_code='GWVOICE_20_S1'},
    @{id=3794; name='HMSAXOPHONE Saxophone Sem 1';      sis_course_code='HMSAXOPHONE_20_S1'},
    @{id=3795; name='JDGUITAR Guitar Sem 1';            sis_course_code='JDGUITAR_20_S1'},
    @{id=3796; name='KSVOICE Voice Sem 1';              sis_course_code='KSVOICE_20_S1'},
    @{id=3797; name='KTBASS Bass Guitar Sem 1';         sis_course_code='KTBASS_20_S1'},
    @{id=3798; name='MFFLUTE Flute Sem 1';              sis_course_code='MFFLUTE_20_S1'},
    @{id=3799; name='MJVOICE Voice Sem 1';              sis_course_code='MJVOICE_20_S1'},
    @{id=3800; name='MKFLUTE Flute Sem 1';              sis_course_code='MKFLUTE_20_S1'},
    @{id=3801; name='NLPIANO Piano Sem 1';              sis_course_code='NLPIANO_20_S1'},
    @{id=3802; name='RSDRUMS Drums Sem 1';              sis_course_code='RSDRUMS_20_S1'},
    @{id=3803; name='RSEUPHONIUM Euphonium Sem 1';      sis_course_code='RSEUPHONIUM_20_S1'},
    @{id=3804; name='RSFRENCHHORN French Horn Sem 1';   sis_course_code='RSFRENCHHORN_20_S1'},
    @{id=3805; name='RSTROMBONE Trombone Sem 1';        sis_course_code='RSTROMBONE_20_S1'},
    @{id=3806; name='RSTRUMPET Trumpet Sem 1';          sis_course_code='RSTRUMPET_20_S1'},
    @{id=3807; name='SBPIANO Piano Sem 1';              sis_course_code='SBPIANO_20_S1'},
    @{id=3808; name='SHTRUMPET Trumpet Sem 1';          sis_course_code='SHTRUMPET_20_S1'},
    @{id=3809; name='SPCELLO Cello Sem 1';              sis_course_code='SPCELLO_20_S1'},
    @{id=3810; name='SPFLUTE Flute Sem 1';              sis_course_code='SPFLUTE_20_S1'},
    @{id=3811; name='SPPIANO Piano Sem 1';              sis_course_code='SPPIANO_20_S1'},
    @{id=3812; name='SPVIOLIN Violin Sem 1';            sis_course_code='SPVIOLIN_20_S1'},
    @{id=3813; name='SWBASS Bass Guitar Sem 1';         sis_course_code='SWBASS_20_S1'},
    @{id=3814; name='SWGUITAR Guitar Sem 1';            sis_course_code='SWGUITAR_20_S1'}


# We must first alter their SIS_COURSE_CODES in Canvas to append '..._DELETED' so that their 
# course codes can be re-used later (Canvas does not actually delete courses when they are deleted
# by users, so their course codes cannot be re-used unless they are changed before deletion).

ForEach ($course in $courses) {

    Write-Host "Modifying course code for: $($course.name)"

    $body = @{
        'course[sis_course_id]'="$($course.sis_course_code)_DELETED"}
    $URI = "https://<HOSTNAME>:443/api/v1/courses/$($course.id)"

    Write-Host `t$uri
    Write-Host "`tNew Course Code: $($body.item('course[sis_course_id]'))"
    
    $response = Invoke-WebRequest `
        -URI $URI `
        -Headers $headers `
        -Method PUT `
        -Body $body `
        -ContentType 'multipart/form-data'

    $response_content = $response.content | ConvertFrom-JSON

    if ($response.StatusDescription -EQ 'OK') { 
        Write-Host "`tOK, SIS_COURSE_ID was set to: $($response_content.sis_course_id)"
    } else {
        Write-Host "`tThere was a problem..."
        Write-Host '---------------------------------------------'
        Write-Host 'RESPONSE'
        Write-Host '---------------------------------------------'
        $response | format-list
        Write-Host '---------------------------------------------'
        Write-Host 'RESPONSE CONTENT'
        Write-Host '---------------------------------------------'
        $response_content | format-list
        
        # Skip to next course. 
        Continue
    }

    Write-Host "`tDeleting course..."
    $URI = "https://<HOSTNAME>:443/api/v1/courses/$($course.id)?event=delete"

    $response = Invoke-WebRequest `
        -URI $URI `
        -Headers $headers `
        -Method DELETE 

    $response_content = $response.content | ConvertFrom-JSON

    if ($response.StatusDescription -EQ 'OK') { 
        Write-Host "`tOK, course $($course.id) [$($course.name)] was deleted successfully."
    } else {
        Write-Host "`tThere was a problem..."
        Write-Host '---------------------------------------------'
        Write-Host 'RESPONSE'
        Write-Host '---------------------------------------------'
        $response | format-list
        Write-Host '---------------------------------------------'
        Write-Host 'RESPONSE CONTENT'
        Write-Host '---------------------------------------------'
        $response_content | format-list
    }

}
