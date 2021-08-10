
$rootFolder        = (Split-Path $MyInvocation.MyCommand.path)
$logFilePath       = "$rootFolder\Logs\MaintainReliefContent_$(get-date -format 'yyyy.MM.dd_hh.mm').log"

# Canvas API token for selby_b@woodcroft.sa.edu.au
$token      = '<TOKEN>'
$headers    = @{Authorization="Bearer $token"}

# If any extra courses should be updated but they do not appear in the CanvasEnrollments synergy query, 
# add their SIS IDs here. 
$extraCourseSisIds = @()


$script:moduleName = 'Relief Information - DO NOT PUBLISH!'
$script:moduleRank = 1
$script:pageName = 'Relief Information'
$script:pageContent = '
    <p>1. Enter your relief information for students using Canvas Announcements. Delay posting is a nice feature to consider as you can set it so that the students receive announcements as they enter the class. The relief teacher can access this information.</p>
    <p><strong>2. Any personal information relating to students learning needs will be emailed to the relevant relief teacher.</strong></p>
    <p>3. Any specific information that you have for relief teachers can be entered at the bottom of this page (see below). For example "Please don''t sit these students together." It is not required but could be helpful if you have some specific information for the teacher.</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>
        <span style="color: #e03e2d; font-size: 48pt;"><strong>Do not project!</strong></span>
    </p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <p>&nbsp;</p>
    <hr />
    <p>Enter class relief information here.&nbsp;</p>'


# ============================================================================================================================
# FUNCTIONS
# ============================================================================================================================


function CountReliefModules {
    param (
        [Parameter(Mandatory=$true)] [int] $CanvasCourseId
    )

    $form = @{
        search_term="$script:moduleName"}

    $response = Invoke-RestMethod `
        -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/modules" `
        -method GET `
        -Headers $headers `
        -ContentType multipart/form-data `
        -Body $form `
        -FollowRelLink

    $modules = $response | ForEach-Object {$_}

    return $modules.count
}



function CountReliefPages {
    param (
        [Parameter(Mandatory=$true)] [int] $CanvasCourseId
    )

    $form = @{
        search_term="$script:pageName"}

    $response = Invoke-RestMethod `
        -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/pages" `
        -method GET `
        -Headers $headers `
        -ContentType multipart/form-data `
        -Body $form `
        -FollowRelLink

    $pages = $response | ForEach-Object {$_}

    return $pages.count 
}


function CountReliefModulePageLinks {
    param (
        [Parameter(Mandatory=$true)] [int] $CanvasCourseId,
        [Parameter(Mandatory=$true)] [int] $ModuleId
    )

    $response = Invoke-RestMethod `
        -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/modules/$ModuleId/items" `
        -Headers $headers `
        -method GET `
        -FollowRelLink
    
    $linkedPages = $response | ForEach-Object {$_}

    return $linkedPages.count
}


function CreateReliefModule{
    param (
        [Parameter(Mandatory=$true)] [int] $CanvasCourseId
    )

    # Returns: 
    #   Failure = 0
    #   Success = Canvas ID of module created.

    try {

        $form = @{
            'module[name]' = "$script:moduleName"
            'module[position]' = "$script:moduleRank"
        }

        $response = Invoke-RestMethod `
            -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/modules" `
            -Headers $headers `
            -method POST `
            -ContentType 'multipart/form-data' `
            -Form $form

    } catch {
        Write-Error $_
        return 0
    }

    # Return ID of created module. 
    return $response.id
}



function CreateReliefPage{
    param (
        [Parameter(Mandatory=$true)] [int] $CanvasCourseId,
        [Parameter(Mandatory=$true)] [int] $ModuleId
    )

    # Returns: 
    #   Failure = 0
    #   Success = Canvas ID of module that the new page has been successfuled created within. 


    # =======================================================================================================
    # Create the new page. 
    # =======================================================================================================

    try {

        $form = @{
            'wiki_page[title]' = "$script:pageName"
            'wiki_page[editing_roles]' = 'teachers'
            'wiki_page[published]' = 'false'
        }

        $response = Invoke-RestMethod `
            -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/pages" `
            -Headers $headers `
            -method POST `
            -ContentType 'multipart/form-data' `
            -Form $form

    } catch {
        Write-Error $_
        return 0
    }

    $pageSuffix = $response.html_url.split('/')[-1]

    # =======================================================================================================
    # Add content to the page. 
    # =======================================================================================================

    try {

        $form=@{
            'wiki_page[body]'="$script:pageContent"
        }
    
        $response = Invoke-RestMethod `
            -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/pages/$pageSuffix" `
            -Headers $headers `
            -method PUT `
            -ContentType 'multipart/form-data' `
            -Form $form

    } catch {
        Write-Error $_
        return 0
    }


    # =======================================================================================================
    # Link the created page to the new module. 
    # =======================================================================================================

    try {

        $form = @{
            'module_item[title]' = "$script:pageName"
            'module_item[type]' = 'Page'
            'module_item[position]' = '1'
            'module_item[page_url]' = "$pageSuffix"
        }

        $response = Invoke-RestMethod `
            -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/modules/$ModuleId/items" `
            -Headers $headers `
            -method POST `
            -ContentType 'multipart/form-data' `
            -Form $form

    } catch {
        Write-Error $_
        return 0
    }

    # Return: ID of linked module. 
    return $response.id
}



function MaintainReliefModule{
    param (
        [Parameter(Mandatory=$true)] [int] $CanvasCourseId
    )

    # Returns: 
    #   Failure = 0
    #   Success = Canvas ID of module maintained successfully.

    try {

        # Get the ID of the existing relief module. 

        $form = @{
            search_term="$script:moduleName"}
    
        $response = Invoke-RestMethod `
            -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/modules" `
            -method GET `
            -Headers $headers `
            -ContentType multipart/form-data `
            -Body $form `
            -FollowRelLink

        $moduleId = $response.id

        # Perform maintenance on the relief module. 

        $form = @{
            'module[position]'  = 1
            'module[published]' = 'False'
        }

        $response = Invoke-RestMethod `
            -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/modules/$moduleId" `
            -method PUT `
            -Headers $headers `
            -ContentType multipart/form-data `
            -Body $form `
            -FollowRelLink

    } catch {
        Write-Error $_
        return 0
    }

    # Return the ID of the module we just maintained. 
    return $response.id
}



function MaintainReliefPage {
    param (
        [Parameter(Mandatory=$true)] [int] $CanvasCourseId,
        [Parameter(Mandatory=$true)] [int] $ModuleId
    )

    # Returns: 
    #   Failure = 0
    #   Success = 1

    # Get the relief information page. We assume that only one will be returned here (dodgy but will have to do for now.)

    try {

        $form = @{
            search_term="$script:pageName"}

        $response = Invoke-RestMethod `
            -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/pages" `
            -method GET `
            -Headers $headers `
            -ContentType multipart/form-data `
            -Body $form `
            -FollowRelLink

        $pages = $response | ForEach-Object {$_}
        $page = $pages[0]
        $pageUrl = $page.url 

    } catch {
        Write-Error $_
        return 0
    }

    # Maintain the existing page publication state etc. 

    try {

        $form = @{
            'wiki_page[title]' = "$script:pageName"
            'wiki_page[editing_roles]' = 'teachers'
            'wiki_page[published]' = 'false'
        }

        $response = Invoke-RestMethod `
            -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/pages/$pageUrl" `
            -method PUT `
            -Headers $headers `
            -ContentType multipart/form-data `
            -Body $form `
            -FollowRelLink

    } catch {
        Write-Error $_
        return 0
    }
    
    # Confirm that the relief module contains the correct relief page item. 

    $form = @{
        search_term="$script:pageName"}

    $response = Invoke-RestMethod `
        -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/modules/$ModuleId/items" `
        -Headers $headers `
        -method GET `
        -form $form `
        -ContentType multipart/form-data `
        -FollowRelLink
    
    $linkedPages = $response | ForEach-Object {$_}

    if ($linkedPages.count -EQ 0) {

        # Link the current page to the relief module. 
        try {

            $form = @{
                'module_item[title]' = "$script:pageName"
                'module_item[type]' = 'Page'
                'module_item[position]' = '1'
                'module_item[page_url]' = "$pageUrl"
            }

            $response = Invoke-RestMethod `
                -uri "https://woodcroft.instructure.com:443/api/v1/courses/$CanvasCourseId/modules/$ModuleId/items" `
                -Headers $headers `
                -method POST `
                -ContentType 'multipart/form-data' `
                -Form $form

        } catch {
            Write-Error $_
            return 0
        }    
    } 
    elseif ($linkedPages.count -GT 1) {
        Write-Error "ERROR: Multiple matching page links detected in relief module $ModuleId for course $CanvasCourseId."
        return 0
    }

    return 1
}


function MaintainAllReliefContent {

    Write-Output "Started at $(Get-Date -Format 'HH:mm:ss')`n" 

    # Get the SIS IDs for the current set of courses being taught, as well as any extra courses. 

    $currentYear = Get-Date -format yyyy
    $currentSemester = if ([int](Get-Date -format MM) -LE 6) { 1 } else { 2 }

    $canvasSisIds = Invoke-Sqlcmd `
        -server synergy `
        -query "select distinct CanvasCourseId from woodcroft.utfCanvasEnrollments($currentYear, $currentSemester)"

    $currentCourseSisIds = $canvasSisIds | Foreach-Object {$_[0]}
    $currentCourseSisIds += $extraCourseSisIds

    # Get all courses for the current account. 
    $response = Invoke-RestMethod `
        -uri 'https://woodcroft.instructure.com/api/v1/accounts/1/courses' `
        -Headers $headers `
        -Method GET `
        -FollowRelLink

    # Filter the list of all courses to include only those currently being taught. 
    $currentCourses = $response | ForEach-Object {$_} 
        | Where-Object {$_.sis_course_id -IN $currentCourseSisIds}


    Write-Output "$($currentCourses.count) current courses will be scanned. " 
    Write-output "========================================================================================================================================="
    Write-output ("{0,-20} | {1,-65} | {2,8} | {3,-14} | {4,-12}" -f 'SisCourseId', 'CourseName', 'CanvasId', 'Content', 'Action') 
    Write-output "========================================================================================================================================="


    foreach($course in $currentCourses) {

        $logLine = ("{0,-20} | {1,-65} | {2,8}" -f `
            $course.sis_course_id, `
            $course.name, `
            $course.id) 
        
        $logLineSuffix = '{0} | {1,14} | {2,-60}'

        if($course.sis_course_id -EQ $nothing) {
            Write-Output ($logLineSuffix -f $logLine, 'Course', 'SKIPPED')
            continue
        }
    
        # Check if a single relief module exists. If so, maintain it. If not, create it. 
        $nReliefModules = CountReliefModules -CanvasCourseId $course.id
        if($nReliefModules -EQ 1) {
            $moduleId = MaintainReliefModule -CanvasCourseId $course.id
            if($moduleId -EQ 0) {
                Write-Output ($logLineSuffix -f $logLine, 'Module', 'ERROR maintaining relief module.')
            }
            else {
                Write-Output ($logLineSuffix -f $logLine, 'Module', 'MAINTAINED')
            }
        }
        elseif($nReliefModules -EQ 0) {
            $moduleId = CreateReliefModule -CanvasCourseId $course.id
            if($moduleId -EQ 0 -or $moduleId -eq $nothing) {
                Write-Output ($logLineSuffix -f $logLine, 'Module', 'ERROR creating relief module.')
            }
            else {
                $nReliefModules = 1
                Write-Output ($logLineSuffix -f $logLine, 'Module', 'CREATED')
            }
        }
        else {
            Write-Output ($logLineSuffix -f $logLine, 'Module', 'ERROR - Wrong number of relief modules.')
        }

        # If a relief module exists, confirm that it only has a single page link within it. 
        if ($nReliefModules -EQ 1) {
            $nReliefModulePageLinks = CountReliefModulePageLinks -CanvasCourseId $course.id -ModuleId $moduleId
            if($nReliefModulePageLinks -EQ 1) {
                Write-Output ($logLineSuffix -f $logLine, 'ModulePageLinks', 'OK')
            }
            elseif($nReliefModulePageLinks -EQ 0) {
                Write-Output ($logLineSuffix -f $logLine, 'ModulePageLinks', 'ERROR - No page links found under Relief module.')
            }
            else {
                Write-Output ($logLineSuffix -f $logLine, 'ModulePageLinks', 'ERROR - Wrong number of page links under Relief Module.')
            }


            $nReliefPages = CountReliefPages -CanvasCourseId $course.id
            if($nReliefPages -EQ 1) {
                if( (MaintainReliefPage -CanvasCourseId $course.id -ModuleId $moduleId) -EQ 0) {
                    Write-Output ($logLineSuffix -f $logLine, 'Page', 'ERROR maintaining relief page.')
                }
                else {
                    Write-Output ($logLineSuffix -f $logLine, 'Page', 'MAINTAINED')
                }
            }
            elseif($nReliefPages -EQ 0) {
                if( (CreateReliefPage -CanvasCourseId $course.id -ModuleId $moduleId) -EQ 0) {
                    Write-Output ($logLineSuffix -f $logLine, 'Page', 'ERROR creating relief page.')
                }
                else {
                    Write-Output ($logLineSuffix -f $logLine, 'Page', 'CREATED')
                }
            }
            else {
                Write-Output ($logLineSuffix -f $logLine, 'Page', 'ERROR - Wrong number of relief pages.')
            }
        }
    }

    Write-Output "Finished at $(Get-Date -Format 'HH:mm:ss')`n" 
}


# ============================================================================================================================
# MAIN
# ============================================================================================================================


MaintainAllReliefContent *>&1 > "$logFilePath" 
