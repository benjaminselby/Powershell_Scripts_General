
# This copies all reports for students with ID numbers specified in an array 
# to an output folder. This is useful where a bunch of student reports might need 
# to be extracted, e.g. to mail reports for international students to Wendy Huggins. 


$inputFolder = '<FOLDER_PATH>'
$outputFolder = '<FOLDER_PATH>'

$studentIds = @(<STUDENT_ID_LIST>) 


foreach ($id in $studentIds){

    $files = Get-ChildItem -Path $inputFolder -Recurse | Where-Object {$_.name -match "$id.*" -and $_.fullName -notMatch '.*\!JUNK.*'}
    
    if ($files.count -EQ 0) {
        Write-Host "ERROR: No file found for id: $id`n"
        Continue
    } elseif ($files.count -GT 1) {
        Write-Host "WARNING: $($files.count) files found for id: $id"
    } 

    foreach ($file in $files) {
        Write-Host "Copying: $($file.FullName)"
        Copy-Item -Path $file.FullName -Destination $outputFolder
    }

    Write-Host "`n"
}