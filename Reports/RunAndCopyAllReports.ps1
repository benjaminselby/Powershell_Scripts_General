

$myRootFolder   = Split-Path $MyInvocation.MyCommand.path
$logFilePath    = "$myRootFolder\Logs\RunAndCopyReports_$(get-date -format 'yyyy.MM.dd_hh.mm').log"


################################################################################################################
# FUNCTIONS
################################################################################################################


Function RunSubscription {

    param (
        [Parameter(Mandatory=$true)]
        [string] $subscriptionTitle,
        # Root folder to contain the output PDFs produced by SSRS.
        [Parameter(Mandatory=$true)]
        [string] $ssrsOutputPath
    )

    $sqlSubscriptionInfo    = "select SubscriptionID from Subscriptions where Description = '$subscriptionTitle'"
    $subscriptionInfo       = Invoke-Sqlcmd -server <SERVER_NAME> -database ReportServer -query $sqlSubscriptionInfo
    if ($subscriptionInfo -EQ $nothing) {
        Write-Output "ERROR: Could not get subscription info for job. `nTITLE: [$subscriptionTitle]."
        Return
    }

    $subscriptionId = $subscriptionInfo.SubscriptionId.ToString()

    $sqlJobInfo = "select ScheduleId from ReportSchedule where SubscriptionID = '$subscriptionId'"
    $jobInfo = Invoke-Sqlcmd -server <SERVER_NAME> -database ReportServer -query $sqlJobInfo
    if ($jobInfo -EQ $nothing) {
        Write-Output "ERROR: Could not get info for job.`nTITLE: $subscriptionTitle `nSUBSCRIPTION_ID: $subscriptionId"
        Return
    }

    $jobId = $jobInfo.ScheduleId.ToString()

    Write-Output "Starting job at $(get-date -f 'yyyy.MM.dd HH:mm').`nTITLE: $subscriptionTitle `nSUBSCRIPTION_ID: $subscriptionId `nJOB_ID: $jobId"
    Invoke-Sqlcmd `
        -Server <SERVER_NAME> `
        -Database MSDB `
        -Query "EXEC sp_start_job @job_name ='$jobId'"

    do {
        # Wait for a bit to give the job a chance to start.
        Start-Sleep -Seconds 30

        $sqlPendingTasks = "select * from Notifications where SubscriptionID = '$subscriptionId'"
        $pendingTasks = Invoke-Sqlcmd `
            -server <SERVER_NAME> `
            -database ReportServer `
            -query $sqlPendingTasks
        
        Write-Output "$($pendingTasks.count) items remaining to be processed."

    } until ($pendingTasks.count -LE 0)


    $sqlJobInfo = "select * from Subscriptions where SubscriptionID = '$subscriptionId'"
    $jobInfo = Invoke-Sqlcmd `
        -server <SERVER_NAME> `
        -database ReportServer `
        -query $sqlJobInfo        

    Write-Output "Report processing finished at $(get-date -f 'yyyy.MM.dd HH:mm') with status: [$($jobInfo.LastStatus)]."
}


################################################################################################################
# MAIN
################################################################################################################



################################################################################################################
# MIDDLE & SENIOR SCHOOL
################################################################################################################

# Year 6 is technically in Junior School, but their report is based on the Middle/Senior reports. 
$startYear = 6
$endYear = 12
$ssrsOutputPath = '<FOLDER_PATH>'

RunSubscription `
    -subscriptionTitle  'Middle and Senior School Reports - 2021 T2' `
    -ssrsOutputPath  $ssrsOutputPath  `
    *>&1 `
    | Out-File -FilePath "$logFilePath" -Append

Write-Output "Copying Middle & Senior School reports from N to G drive..." | Out-File -FilePath "$logFilePath" -Append

foreach ($year in $startYear..$endYear) {

    $copyToFolder = "<FOLDER_PATH>\Year $year"

    # First test for existence of output folder. If it doesn't exist, create it. 
    if ((Test-Path "$copyToFolder") -EQ $false) {
        New-Item -ItemType Directory "$copyToFolder" | Out-Null
    }

    # Reports in the source folder are not sorted into year-level folders, but we identify them 
    # by file name match, and output them to separate destination folders by year level. 
    Copy-Item `
        "$ssrsOutputPath\* - Year $year *.pdf" `
        "$copyToFolder"
    
    Write-Output "Copied all Year $year report PDFs`n`tFROM: $ssrsOutputPath`n`tTO:  $copyToFolder" | Out-File -FilePath "$logFilePath" -Append
} 


Write-Output "Creating combined year-level PDF report documents..." | Out-File -FilePath "$logFilePath" -Append
foreach ($year in $startYear..$endYear) {

    $copiesFolder = "<FOLDER_PATH>\Year $year"

    # Try to write empty string to the output file to see if it is accessible or not (may already exist and be open by a user.)
    $combinedYearPdf = "$copiesFolder\!Y$($year)_AllStudents.pdf"
    try {
        "" | Out-File "$combinedYearPdf" -Append
    } catch {
        Write-Output "ERROR: Could not create file $combinedYearPdf.`n`tIt may be opened by a user." | Out-File -FilePath "$logFilePath" -Append
        Continue
    }

    # PDFTK is a PDF editing command-line utility. 
    pdftk "$copiesFolder\* - Year $year *.pdf"  output $combinedYearPdf
    Write-Output "Created combined year-level PDF at: $combinedYearPdf" | Out-File -FilePath "$logFilePath" -Append
}

Write-Output "Finished Middle and Senior School reports." | Out-File -FilePath "$logFilePath" -Append



################################################################################################################
# JUNIOR SCHOOL
################################################################################################################

$startYear = 1
$endYear = 5
$ssrsOutputPath = '<FOLDER_PATH>'


RunSubscription `
    -subscriptionTitle  'Junior School Reports - 2021 T2' `
    -ssrsOutputPath     $ssrsOutputPath `
    *>&1 `
    | Out-File -FilePath "$logFilePath" -Append

Write-Output "Copying Junior School reports from N to G drive..." | Out-File -FilePath "$logFilePath" -Append

foreach ($year in 1..5) {

    $ssrsFolder = $ssrsOutputPath
    $copiesFolder = "<FOLDER_PATH>\Year $year"

    # First test for existence of output folder. If it doesn't exist, create it. 
    if ((Test-Path "$copiesFolder") -EQ $false) {
        New-Item -ItemType Directory "$copiesFolder" | Out-Null
    }

    # Reports in the source folder are not sorted into year-level folders, but we identify them by file name match, and 
    # output them to separate folders by year level. 
    Copy-Item `
        "$ssrsFolder\* - Year $year *.pdf" `
        "$copiesFolder"
    
    Write-Output "Copied all Year $year report PDFs`n`tFROM: $ssrsOutputPath $year`n`tTO:  $copiesFolder" | Out-File -FilePath "$logFilePath" -Append
} 

Write-Output "Creating combined year-level PDF report documents..." | Out-File -FilePath "$logFilePath" -Append
foreach ($year in 1..5) {

    $copiesFolder = "<FOLDER_PATH>\Year $year"

    # Try to write empty string to the output file to see if it is accessible or not (may already exist and be open by a user.)
    $combinedYearPdf = "$copiesFolder\!Y$($year)_AllStudents.pdf"
    try {
        "" | Out-File "$combinedYearPdf" -Append
    } catch {
        Write-Output "ERROR: Could not create file $combinedYearPdf.`n`tIt may be opened by a user." | Out-File -FilePath "$logFilePath" -Append
        Continue
    }

    pdftk "$copiesFolder\* - Year $year *.pdf"  output $combinedYearPdf
    Write-Output "Created combined year-level PDF at: $combinedYearPdf" | Out-File -FilePath "$logFilePath" -Append
}

Write-Output "Finished Junior School reports." | Out-File -FilePath "$logFilePath" -Append

