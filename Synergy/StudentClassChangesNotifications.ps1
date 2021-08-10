
param (
    [string] $rootFolder            = "$(Split-Path $MyInvocation.MyCommand.path)",
    [string] $logFilePath           = "$rootFolder\Logs\"+$(Get-Date -format 'yyyy.MM.dd')+"_birthdayNotifications.log",
    [string] $script:smtpserver     = '<MAIL_SERVER_NAME>',
    [string] $script:mailSender     = '<EMAIL_ADDRESS>',
    [string] $script:writeToLog     = 'Y',
    [string] $script:imagesFolder   = '<FOLDER_PATH>',
    [string[]] $excludeUserIds      = @() # Staff who do not wish to receive notifications. 
)


FUNCTION SendClassChangeNotifications {

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


