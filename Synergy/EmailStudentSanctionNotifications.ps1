
# Originally, the intention was for BMS to send these emails, but after discussing this with Adrian, 
# we think that it would be best to have a delay on the sending of communications to parents so that
# teachers have a chance to modify detentions etc. in case they make a mistake. So, the process
# has been moved to a script which will run periodically. 
#
#     - Mail to: Teacher setting the detention, TG teacher, Head of Year, 
#         student, and student's contacts. 


param (
    [string] $smtpserver    = '<MAIL_SERVER_NAME>',
    [string] $writeToLog    = 'Y',
    [string] $rootFolder    = "$(Split-Path $MyInvocation.MyCommand.path)",
    [string] $logFilePath   = "$rootFolder\Logs\"+$(Get-Date -format 'yyyy.MM.dd_HH.mm.ss')+"_emailNotifications.log"
)


function Main {

    BEGIN {
        $SMTPClient = New-Object Net.Mail.SmtpClient($smtpServer, 25)

        $emailBodyBegin = '
            <!DOCTYPE html>
            <html>
                <head>          
                    <style>              
                        body    {font-family: calibri;}              
                        h1      {font-size: 200%}              
                        h2      {padding: 5px;}    
                        table.Notification, table.Notification td {
                            border: 1px solid darkgray;
                            border-collapse: collapse;
                            padding: 5px
                        }
                        td.RowHeader {font-weight: bold;}       
                    </style>          
                </head>          
                <body>          
                    <p>
                        This is an automated notification to inform you that the following student sanction has been created.
                    </p>'

        $emailBodyEnd = '
                    <p>
                        If you have any questions about this sanction, please contact the specified staff member.
                    </p>          
                </body>          
            </html>'

        Write-output ("Started at $(Get-Date -format 'yyyy.MM.dd HH:mm:ss').")
    }


    ####################################################################################################################
    ####################################################################################################################


    PROCESS {

        $SanctionsToNotify = Invoke-Sqlcmd `
            -server synergy `
            -query 'exec woodcroft.uspsBmsGetSanctionsToNotify'

        Write-output ("Sanctions to notify:")
        $SanctionsToNotify | format-table 

        foreach($sanction in $SanctionsToNotify) {

            # Skip this student if emails are not enabled for them. 
            $sendEmailsForStudent = Invoke-Sqlcmd `
                -server synergy `
                -query "exec woodcroft.uspsBmsSendEmailsForStudent @StudentId = $($sanction.StudentID)"

            if($sendEmailsForStudent.ReturnValue -NE 1) {
                Write-output ("Email notifications are not enabled for Student: {0} [ID:{1}]. Skipping." `
                    -f $sanction.StudentName, $sanction.StudentID)
                Continue
            }

            ##############################################################################################
            # Compose and send email.
            ##############################################################################################

            Write-output ("Sending email notification - Student: {0} [ID:{1}], StaffMember: {2} [ID:{3}], SanctionType: {4}, SanctionDate: {5}" `
                -f $sanction.StudentName, 
                $sanction.StudentId,
                $sanction.StaffName,
                $sanction.StaffId,
                $sanction.SanctionCode,
                $sanction.SanctionDate.ToString("dd/MM/yyyy"))

            $mailmessage = New-Object System.Net.Mail.MailMessage
            $mailmessage.From = $sanction.StaffEmail
            #$mailmessage.Sender = $sanction.StaffEmail
            $mailmessage.Subject = 'Woodcroft College - Student Sanction Notification' 
            $mailmessage.IsBodyHTML = $true
                
            $mailmessage.Body = $emailBodyBegin

            $mailMessage.Body +="<table class='Notification'>" -f $sanction.StudentName
            $mailMessage.Body +="
                <colgroup>
                    <col span='1' style='width: 150px'/>
                </colgroup>"
            $mailMessage.Body += "<tr><td class='RowHeader'>Student Name:</td><td>{0}</td></tr>" -f $sanction.StudentName
            $mailMessage.Body += "<tr><td class='RowHeader'>Staff Member:</td><td>{0} [{1}]</td></tr>" -f $sanction.StaffName, $sanction.StaffEmail
            $mailMessage.Body += "<tr><td class='RowHeader'>Class:</td><td>{0}</td></tr>" -f $sanction.ClassCode
            $mailMessage.Body += "<tr><td class='RowHeader'>Sanction Type:</td><td>{0}</td></tr>" -f $sanction.SanctionCode
            if([System.DBNull]::Value.Equals($sanction.SanctionDate)) {
                $mailMessage.Body += "<tr><td class='RowHeader'>Sanction Date:</td><td>{0}</td></tr>" -f $sanction.SanctionDate.ToString("yyyy-MM-dd")
            }
            $mailMessage.Body += "<tr><td class='RowHeader'>Reason:</td><td>{0}</td></tr>" -f $sanction.Reason
            if($sanction.SanctionCode -EQ 'Non Submission') {
                $mailMessage.Body += "<tr><td class='RowHeader'>Summative Task:</td><td>{0}</td></tr>" -f $sanction.SummativeTaskName
                $mailMessage.Body += "<tr><td class='RowHeader'>Due date:</td><td>{0}</td></tr>" -f $sanction.SummativeDueDate.ToString("yyyy/MM/dd")
            }
            ElseIf ($sanction.SanctionCode -EQ "Report of Concern") {
                $mailMessage.Body += "<tr><td class='RowHeader'>Current Grade:</td><td>{0}</td></tr>" -f $sanction.CurrentGrade
            }
            $mailMessage.Body += '</table>'

            $mailMessage.Body += $emailBodyEnd         
            
            ##############################################################################################
            # Get the list of email recipients who should be notified for this student. 
            ##############################################################################################

            $emailRecipients = Invoke-Sqlcmd `
                    -server Synergy `
                    -query "EXEC woodcroft.uspsBmsGetEmailRecipients @StudentId=$($sanction.StudentID)"

            # Filter out non-unique email addresses to prevent duplicates. 
            # Emails are not currently personalised, so we don't worry about names. Parents who share an email address
            # will receive only one email. 
            $emailAddresses = $emailRecipients.email | get-unique -AsString

            ##############################################################################################
            # Add my email for now while the system is still new so I can keep an eye on things. Maybe remove later. 
            $mailmessage.To.Add('selby_b@woodcroft.sa.edu.au')
            ##############################################################################################

            foreach($recipientAddress in $emailAddresses) {
                if ($recipientAddress -NE '') {
                    ############################################################################################
                    $mailmessage.To.Add($recipientAddress)
                    ############################################################################################
                }
            }
            
            Write-Output("Recipients: {0}" -f ($mailmessage.To -Join ';'))
            Write-Output("$($mailmessage.Body)")

            ##############################################################################################
            # SEND EMAIL 
            ##############################################################################################
            $SMTPClient.Send($mailmessage)
            ##############################################################################################

            ##############################################################################################
            # Update email record table that the notification for this sanction has been sent. 
            ##############################################################################################

            Write-Output ("Email sent. Updating notification log with sanction sequence number: $($sanction.Seq)")
            invoke-sqlcmd `
                -server synergy `
                -query "exec [woodcroft].[uspuBmsNotificationEmailSent] @SanctionSeq = $($sanction.Seq)"
        }    
    }


    ####################################################################################################################
    ####################################################################################################################


    END {
        Write-output ("Finished at $(Get-Date -format 'yyyy.MM.dd_HH:mm:ss').")
        Write-Output ("========================================================================================")
    }
}


Main *> "$logFilePath"
