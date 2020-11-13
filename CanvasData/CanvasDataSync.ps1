ECHO "Starting sync of Canvas data: $(Get-Date)" 

CanvasDataCLI sync `
	-c c:\Canvas\Canvas_Data_Warehouse\config.js 

ECHO "Finished sync: $(Get-Date)" 


ECHO "-----------------------------------------------"


ECHO "Unpacking data: $(Get-Date)"

CanvasDataCLI unpack `
	-c c:\Canvas\Canvas_Data_Warehouse\config.js `
    -f `
        account_dim `
		assignment_dim `
		assignment_fact `
		conversation_dim `
		conversation_message_dim `
		conversation_message_participant_fact `
		course_dim `
		enrollment_dim `
		enrollment_rollup_dim `
		enrollment_term_dim `
		external_tool_activation_dim `
        external_tool_activation_fact `
        file_dim `
        file_fact `
		group_dim `
		group_fact `
		group_membership_dim `
		group_membership_fact `
		module_dim `
		pseudonym_dim `
		quiz_dim `
		quiz_submission_fact `
		requests `
		submission_dim `
		submission_fact `
		user_dim 
		

ECHO "Finished unpack: $(Get-Date)"


ECHO "-----------------------------------------------"


ECHO "Loading to SQL Server Database: $(Get-Date)"


$SqlOutput = Invoke-Sqlcmd `
	-ServerInstance "TESTSERVER2" `
	-Database "CanvasData" `
	-QueryTimeout 0 `
	-Query "EXEC spLoadCanvasDataAll" 

foreach ($Row in $SqlOutput)
{
    ECHO $Row.ItemArray
}

ECHO "Finished load: $(Get-Date)"

ECHO "Done."

