
$dateTime = Get-Date -Format 'yyyy.MM.dd_HH.mm'

$swapFolder     = "<FOLDER_PATH>"
$archiveFolder  = "<FOLDER_PATH>"

$tableNames = @(
        'dbo.PTInterviews',
        'dbo.SubjectClasses',
        'dbo.SubjectClassStaff',
        'dbo.StudentAssessmentResults',
        'dbo.StudentClasses',
        'dbo.Students',
        'dbo.StudentYears',
        'dbo.uAmsUsers',
        'dbo.uStudentSanctions',
        'dbo.uStudentCounsellorComments',
        'woodcroft.uTutorGroupParticipation')

foreach($tableName in $tableNames) {

    Write-Output "Exporting table [$tableName] to PSV."

    invoke-sqlcmd `
        -server synergy `
        -query "select * from $tableName" `
        | export-csv `
            -path "$($swapFolder)\$($tableName)_$($dateTime).psv" `
            -delim '|' `
            -UseQuotes AsNeeded
}

Write-Output "Creating archive zip file."

Compress-Archive `
    -Path "$($swapFolder)\*.psv" `
    -DestinationPath "$($archiveFolder)\TableArchive_$($dateTime).zip"

Write-Output "Cleaning up swap folder."

Get-ChildItem -Path "$swapFolder\*" -include '*.psv' -file `
    | ForEach-Object {$_.Delete()}
