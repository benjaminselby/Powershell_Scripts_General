
# AUTHOR:   Benjamin Selby
# CREATED:  2021/05/27
#
# This script maintains a set of photographs for staff and students in a particular folder. 
# It checks if an image already exists. If so, it checks how old the image is. If the last 
# modification date of the image is greater than a certain number of days, a new image is 
# extracted from Synergy and saved over the old image. 

param (
    [string] $rootFolder                    = "$(Split-Path $MyInvocation.MyCommand.path)",
    [string] $logFilePath                   = "$rootFolder\Logs\"+$(Get-Date -format 'yyyy.MM.dd')+"_PhotoSync.log",
    [string] $script:writeToLog             = 'Y',
    [string] $script:synergyImagesFolder    = '<FOLDER_PATH>',
    [string] $script:imageFileExtension     = "jpg",
    [int] $script:imageLifetimeDays         = 30
)


####################################################################################################################
# FUNCTIONS
####################################################################################################################

function ExportPhotoFromSynergy {
    param (
        [int] $ID,
        [string] $outputFilePath
    )

    BEGIN {
        Write-Output "Extracting profile photo from Synergy to path: $script:synergyImagesFolder\$imageFileName"
    }

    PROCESS {

        $sqlGetSynergyProfileImage = "
            exec dbo.spsExportSynergyProfileImage 
                @UserId             = $Id, 
                @ExportFolderPath   = '$script:synergyImagesFolder', 
                @FileName           = '$imageFileName'"

        $imageExportProcess = Invoke-Sqlcmd `
            -server TESTSERVER2 `
            -database CanvasAdmin `
            -query $sqlGetSynergyProfileImage

        if ($imageExportProcess.ReturnValue -EQ 0) {
            Write-Output "No image file was exported from Synergy for this user. Exiting."
            Return
        } elseif ($imageExportProcess.ReturnValue -EQ 1) {
            Write-Output "Image file exported from Synergy successfully to [$script:synergyImagesFolder\$imageFileName]."
        } else {
            Write-Output "ERROR: Unknown return value from image export SQL procedure. Exiting process."
            Return
        }
    }

    END {
        # Do nothing. 
    }
}


function PhotoSync {

    param (
        [int] $ID
    )

    BEGIN {

        Write-Output "Starting image sync for user with ID $ID."
        $imageFileName = "$ID.$imageFileExtension"
        $imageFilePath = "$script:synergyImagesFolder\$imageFileName"
    }


    PROCESS {

        [boolean] $doImageExport = $false

        if (Test-Path $imageFilePath) {
            $fileLastEditDays = ([datetime]::Now - (get-item $imageFilePath).LastWriteTime).Days
            Write-output "File was last modified $fileLastEditDays days ago."
            if($fileLastEditDays -GE $script:imageLifetimeDays) {
                Write-Output "File lifetime has expired."
                $doImageExport = $true
            } else {
                Write-Output "File is still current. Nothing to do."
            }    
        } else {
            Write-Output "No image file currently exists for this user."
            $doImageExport = $true
        }

        if($doImageExport) {
            ExportPhotoFromSynergy -ID $ID -imageFilePath "$imageFilePath"
        }

    }

    END {
        
        Write-output "Finished for ID $ID."
        Write-Output "---------------------------------------------------------------------------------------------------`n"    
    }
}


####################################################################################################################
# MAIN
####################################################################################################################


Write-output "Started at $(Get-Date -format 'yyyy.MM.dd HH:mm:ss').`n`n" *>> $logFilePath

$staffAndStudentsList = Invoke-Sqlcmd -server SYNERGY -query 'exec woodcroft.uspsGetAllStaffAndStudentsInfo'

foreach($id in $staffAndStudentsList.ID) {
    PhotoSync -id $id *>> $logFilePath
}

Write-output "Finished at $(Get-Date -format 'yyyy.MM.dd HH:mm:ss')." *>> $logFilePath
Write-output "==============================================================================" *>> $logFilePath
Write-output "==============================================================================`n`n" *>> $logFilePath