
param (
    # This script expects student images to already exist in the following folder. These images are 
    # currently kept up-to-date by a separate scheduled process. Image files are expected to be named
    # using the format STUDENT_ID.jpg. So, a student with Synergy ID = '12345' should have an image 
    # file saved at 'C:\Synergy\Images\12345.jpg'. 
    [string] $imageFolder = 'C:\Synergy\Images',
    # Turn this on when you are ready to send emails. CAUTION. 
    [string] $sendEmails = 'Y'
)


$smtpserver     = '<MAIL_SERVER_NAME>'
$mailSender     = '<EMAIL_ADDRESS>'
$SMTPClient     = New-Object Net.Mail.SmtpClient($smtpServer, 25)


#####################################
# EMAIL TEXT 
#####################################


$emailBodyBegin = @"
<!DOCTYPE html>
<html>
<head>
<style>
    body    {font-family: calibri;}
    h1      {font-size: 200%}
    h2      {padding: 5px;}
    p       {}
    table.myTable   {
        width:100%; 
        border-collapse: collapse;} 
    table.myTable, tr.myTable, td.myTable  {
        padding: 10px;
        border: 2px solid gray}
</style>
</head>
<body>
<p>Dear teacher,</p>
<p>You have been assigned reliefs for classes containing the following students who have 
diverse learning needs. Please read the information below and be sensitive to the 
specific requirements of these students.</p>
<p style='font-weight:bold; color: red'>The following information is confidential - please ensure you are not connected to a projector!</p>
<p>If you require further detail regarding the learning needs of these students, 
please refer to the <a href='https://woodcroft.instructure.com/courses/1085/pages/student-services-contents-page'>
Student Services booklets on Canvas</a>. Alternatively, you 
should contact Heather Harvey or Don Eacott.</p>
<br>
"@

$emailBodyTableBegin = @"
<table class='myTable'>
"@

$emailBodyTableEnd = @"
</table>
"@

$emailBodyEnd = @"
<p>Kind regards,</p>
</body>
</html>
"@


############################################################################################################################
# MAIN
############################################################################################################################


# Get all teachers with reliefs scheduled for today who have not received emails. 

$reliefTeachers = Invoke-SQLcmd `
    -server <SERVER_NAME> `
    -database CanvasAdmin `
    -query "EXEC spsDailyReliefsPendingEmailsStaff"

if ($reliefTeachers.count -EQ 0) {
    Write-Output "No email notifications pending. Exiting."
    Return
}

foreach($reliefTeacher in $reliefTeachers) {

    Write-output ("Processing email notifications for relief teacher {0}: {1} [{2}]." -f `
        $reliefTeacher.Id, 
        $reliefTeacher.Name,
        $reliefTeacher.Email)

    # If the relief teacher email is not in the Woodcroft domain, do not proceed. 
    if ( !($reliefTeacher.email -MATCH '^.+@woodcroft.sa.edu.au$') ) {
        Write-Output( `
            "ERROR: Relief teacher does not have a valid Woodcroft email address. Skipping." -f `
            $reliefTeacher.Id, 
            $reliefTeacher.Name,
            $reliefTeacher.Email)
        Continue
    }

    $reliefClasses = Invoke-SQLcmd `
        -server TESTSERVER2 `
        -database CanvasAdmin `
        -query "EXEC spsDailyReliefsPendingEmailsClassesForStaff @staffid = $($reliefTeacher.Id)"

    if($reliefClasses.count -EQ 0) {
        # This may happen if a teacher is relieving a class with 0 students enrolled.
        Write-Output "No relief classes containing enrolled students found for this teacher. Skipping."
        Continue
    }

    $mailmessage = New-Object System.Net.Mail.MailMessage
    $mailmessage.from = $mailSender

    ##############################################################################################
    # EMAIL RECIPIENT SET HERE - MODIFY FOR TESTING VS. PRODUCTION!!!
    ##############################################################################################
    $mailmessage.To.add($reliefTeacher.email)
    ##############################################################################################

    $mailmessage.Subject = 'Daily Reliefs - Diverse Learning Needs Notification' 
    $mailmessage.IsBodyHTML = $true
    $mailmessage.Body = $emailBodyBegin

    # For each class, we will determine whether or not a notification is required and store this value in a hashtable.  
    # If no students in a class have diverse learning needs, a notification is not required.
    $classNotificationRequired = @{}

    foreach ($reliefClass in $reliefClasses) {
    
        $studentRecords = Invoke-Sqlcmd `
            -server <SERVER_NAME> `
            -database CanvasAdmin `
            -query "EXEC dbo.spsStudentsForClass @classcode='$($reliefClass.ClassCode)'" 

        if($studentRecords.count -EQ 0) {
            Write-output "There are no students in class [$($reliefClass.ClassCode): $($reliefClass.Description)] with diverse learning needs."
            Write-Output "No email required. Skipping."
            $classNotificationRequired["$($reliefClass.ClassCode)"] = $False
            Continue
        } 

        # One or more students in this class have diverse learning needs. 
        $classNotificationRequired["$($reliefClass.ClassCode)"] = $True

        $mailmessage.Body += "<h1>$($reliefClass.ClassCode): $($reliefClass.Description)</h1>"
        $mailmessage.Body += $emailBodyTableBegin

        foreach($student in $studentRecords) {

            $mailmessage.body += "<tr class='myTable'>"

            # Add image for each student in first cell of each row.

            $mailmessage.body += "<td class='myTable' style='width:20%'>"

            $imageFilePath = "$imageFolder\$($student.id).jpg"
            if(Test-Path $imageFilePath) {
                $imageAttachment = new-object Net.Mail.Attachment("$imageFilePath")
                $imageAttachment.ContentType.MediaType = 'image/jpg'
                $imageAttachment.ContentId = "Attachment_$($student.id)"        
                $mailmessage.Attachments.Add($imageAttachment)
                $mailmessage.body += "<img src='cid:Attachment_$($student.id)' />"
                # Use the following if creating an HTML file for testing instead of an email. 
                # $mailmessage.body += "<img src='$imageFolder\$($student.id).bmp' />"        
            } else {
                $mailmessage.body += "No Image Availble."
            }

            $mailmessage.body += "</td>"

            # Student Services Information.
            $mailmessage.body += "<td class='myTable'>"
            $mailmessage.body += "<h2>$($student.Name) [$($student.Id)]</h2>"
            $mailmessage.body += "<p>"
            $mailmessage.body += $($student.CriticalInfo).split("`n") | Foreach-Object {"$_<br>"}
            $mailmessage.body += "</p>"
            $mailmessage.body += "</td>"

            $mailmessage.body += '</tr>'
        }

        $mailmessage.body += $emailBodyTableEnd
        $mailmessage.body += "<br>"
    }

    $mailmessage.body += $emailBodyEnd

    if ($classNotificationRequired.ContainsValue($true) -AND $sendEmails -EQ 'Y') {

        Write-output "`n`nMailing to: $($reliefTeacher.Name) [$($reliefTeacher.Email)]`n"
        Write-Output $mailmessage.body

        #################################################################################################
        # SEND EMAIL.
        $SMTPClient.Send($mailmessage)
        #################################################################################################

        # Update relief teacher emails log table to indicate that email has been sent. 
        foreach ($reliefClass in $reliefClasses) {
            if($classNotificationRequired["$($reliefClass.ClassCode)"] -EQ $true) {
                $rowsAffected = Invoke-Sqlcmd `
                    -Server <SERVER_NAME> `
                    -Database CanvasAdmin `
                    -Query "EXEC spuDailyReliefsEmailSent @StaffId = $($reliefTeacher.Id), @ClassCode = '$($reliefClass.ClassCode)'"
                Write-Debug "Updated $($rowsAffected.ReturnValue) records in relief teacher emails log table."
                # ? Check for zero rows updated here?
            }
        }
    } 
    
    Write-Output "Finished notification emails for this staff member."
    Write-Output "---------------------------------------------------------------------------------------------------`n"
}

Write-Output "Finished notification emails for all staff. Exiting.`n"

