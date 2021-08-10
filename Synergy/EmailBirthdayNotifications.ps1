
# Note that this script does not log emails sent. So, if it is run twice, it will re-send any emails
# sent on the first run. TODO: Implement logging service? 

param (
    [string] $rootFolder            = "$(Split-Path $MyInvocation.MyCommand.path)",
    [string] $logFilePath           = "$rootFolder\Logs\"+$(Get-Date -format 'yyyy.MM.dd')+"_birthdayNotifications.log",
    [string] $script:smtpserver     = '<MAIL_SERVER_NAME>',
    [string] $script:mailSender     = '<EMAIL_ADDRESS>',
    [string] $script:writeToLog     = 'Y',
    [string] $script:imagesFolder   = '<FOLDER_PATH>',
    [string[]] $userIds             = @(<USER_ID_LIST) 
)



############################################################################################################################
# FUNCTIONS
############################################################################################################################


FUNCTION SendBirthdayNotifications {

    param (
        [int] $userId,
        [int] $nDaysAhead = 7
    )


    BEGIN {

        $SMTPClient     = New-Object Net.Mail.SmtpClient($script:smtpServer, 25)

        $emailBodyBegin = "
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
        "

        $emailBodyTableBegin = "<table class='myTable'>"

        $emailBodyTableEnd = "</table>
            </br></br>"

        $emailBodyEnd = "
            </body>
            </html>"

        $mailmessage = New-Object System.Net.Mail.MailMessage
        $mailmessage.from = $script:mailSender

        ##############################################################################################
        # EMAIL RECIPIENT SET HERE 
        ##############################################################################################
        $recipientEmail = (invoke-sqlcmd -server SYNERGY -query "SELECT OccupEmail FROM Community WHERE ID = $userId").OccupEmail
        $mailmessage.To.add($recipientEmail)
        ##############################################################################################

        $mailmessage.Subject = 'Upcoming Birthday Notifications' 
        $mailmessage.IsBodyHTML = $true
        $mailmessage.Body = $emailBodyBegin
    }


    ############################################################################################################################
    ############################################################################################################################


    PROCESS {

        $upcomingBirthdays = Invoke-SQLcmd `
            -server SYNERGY `
            -query "EXEC woodcroft.uspsGetBirthdaysToNotifyUser 
                @userId = $userId, 
                @ndaysAhead = $nDaysAhead"

        if ($upcomingBirthdays.count -EQ 0) {
            $mailMessage.Body +=  "<p>There are no birthdays in the next $nDaysAhead days.</p>"
            Return
        }
        else {

            $nStudentBirthdays = ($upcomingBirthdays | where-object {$_.status -EQ 'Student'}).count
            $nStaffBirthdays = ($upcomingBirthdays | where-object {$_.status -EQ 'Staff'}).count

            if ($nStudentBirthdays -GT 0) {
                $mailMessage.Body +=  "<p>$nStudentBirthdays students have birthdays in the next $nDaysAhead days.</p>"
            }

            if ($nStaffBirthdays -GT 0) {
                $mailMessage.Body +=  "<p>$nStaffBirthdays staff members have birthdays in the next $nDaysAhead days.</p>"
            }


            $mailMessage.Body += $emailBodyTableBegin

            foreach ($birthday in $upcomingBirthdays) {
                
                $mailmessage.body += "<tr class='myTable'>"

                # Add image for each person in first cell of each row.
                $mailmessage.body += "<td class='myTable' style='width:20%'>"
                $profileImagePath = "$script:imagesFolder\$($birthday.ID).jpg"
                if(Test-Path $profileImagePath){
                    $imageAttachment = new-object Net.Mail.Attachment("$profileImagePath")
                    $imageAttachment.ContentType.MediaType = 'image/jpg'
                    $imageAttachment.ContentId = "Attachment_$($birthday.Id)"        
                    $mailmessage.Attachments.Add($imageAttachment)
                    $mailmessage.body += "<img src='cid:Attachment_$($birthday.Id)' />"
                }   
                else {
                    $mailMessage.Body += 'No image available.'
                }             
                $mailmessage.body += "</td>"
    
                # Personal information in next column of this row. 
                $mailmessage.body += "<td class='myTable'>"
                $mailmessage.body += "<h2>$($birthday.FullName)</h2>"
                $mailmessage.Body += "<i>$($birthday.Status)</i></br>"
                if ($birthday.Status -EQ 'Student') {
                    $mailmessage.body += "Classes: $($birthday.ClassesForStaffMember)</br>"
                } elseif ($birthday.Status -EQ 'Staff') {
                    $mailmessage.body += "Classification: $($birthday.StaffCategory)</br>"
                } 
                
                $mailmessage.body += "Birth date: {0}/{1:d2}/{2}</br>" -f
                    $birthday.BirthDate.Day,
                    $birthday.BirthDate.Month,
                    $birthday.BirthDate.Year

                if($eventDate.Date -EQ (Get-Date).Date) {
                    $mailmessage.body += "Turning $($birthday.AgeAtBirthday) years old today."
                } else {
                    $mailmessage.body += "Turning  $($birthday.AgeAtBirthday) years old on $($birthday.BirthdayDayOfWeek)."
                }

                $mailmessage.body += '</td></tr>'
            }
        }
                        
        $mailMessage.Body += $emailBodyTableEnd
        $mailMessage.Body += $emailBodyEnd

    }

    END {
        Write-output "`n`nMailing to: $userId`n"
        Write-Output $mailmessage.body

        ############################################################################################################
        ############################################################################################################
        $SMTPClient.Send($mailmessage)
        ############################################################################################################
        ############################################################################################################

        Write-Output "Finished notification emails for this staff member."
        Write-Output "---------------------------------------------------------------------------------------------------`n"    
    }

}



############################################################################################################################
# MAIN
############################################################################################################################


Write-output "Started at $(Get-Date -format 'yyyy.MM.dd HH:mm:ss')." *>> $logFilePath

foreach($userId in $userIds) {
    SendBirthdayNotifications -userId $userId *>> $logFilePath
}

Write-output "Finished at $(Get-Date -format 'yyyy.MM.dd HH:mm:ss')." *>> $logFilePath
Write-Output "====================================================================================================================" *>> $logFilePath
Write-Output "====================================================================================================================`n`n" *>> $logFilePath

