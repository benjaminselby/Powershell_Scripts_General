
# AUTHOR:   Benjamin Selby
# CREATED:  2021/05/27
#
# This script maintains a set of photographs for staff and students in a particular folder. 
# It checks if an image already exists. If so, it checks how old the image is. If the last 
# modification date of the image is greater than a certain number of days, a new image is 
# extracted from Synergy and saved over the old image. 
#
# MODIFICATIONS
# 
#   [2022.03.01 SELBY_B] Included ability to output a ZIP file containing all images 
#       to be used by the Library to import images into OLIVER system via a scheduled 
#       regular import. 
#   [2022.03.04 SELBY_B] Library have changed their strategy for importing images, so 
#       removed the library ZIP file export (keep code just in case it's required in future.)
#   [2022.08.11 selby_b] Added photo sync with General Access/Daily Organiser folder. 
#       This required incorporation of the SCALE.BAT program to reduce the size of exported
#       images so they display correctly in GA. 
#
# ===============================================================================================================


param (
    [string] $rootFolder                    = "$(Split-Path $MyInvocation.MyCommand.path)",
    [string] $logFilePath                   = "$rootFolder\Logs\"+$(Get-Date -format 'yyyy.MM.dd_HH.mm.ss')+"_PhotoSync.log",
    [string] $synergyImagesFolder           = 'C:\Synergy\Images',
    [string] $imageFileExtension            = "jpg",
    [int]    $imageLifetimeDays             = 7,
    [string] $syncGeneralAccess             = 'Y',
    [string] $generalAccessFolder           = '\\[PATH]\Images for Synergy'
    # [string] $createLibraryZip              = 'Y',
    # [string] $libraryZipFile                = '\\[PATH]\OLIVER\SynergyImages.zip'
)


####################################################################################################################
# FUNCTIONS
####################################################################################################################

function ExportPhotoFromSynergy {
    param (
        [int]       $ID,
        [string]    $outputFolder,
        [string]    $fileName,
        [Boolean]   $thumbnail
    )

    Write-Host "Extracting profile photo from Synergy to path: $outputFolder\$fileName"

    $thumbnailFlag = if ($thumbnail) { 1 } else { 0 }

    $sqlGetSynergyProfileImage = "
        exec dbo.spsExportSynergyProfileImage 
            @UserId             = $ID, 
            @ExportFolderPath   = '$outputFolder', 
            @FileName           = '$fileName',
            @Thumbnail          = $thumbnailFlag"

    $imageExportProcess = Invoke-Sqlcmd `
        -server TESTSERVER2 `
        -database Woodcroft `
        -query $sqlGetSynergyProfileImage

    if ($imageExportProcess.ReturnValue -EQ 0) {
        Write-Host "No image file was exported from Synergy for this user. Exiting."
        Return $false
    } elseif ($imageExportProcess.ReturnValue -EQ 1) {
        Write-Host "Image file exported from Synergy successfully to [$outputFolder\$imageFileName]."
        Return $true
    } else {
        Write-Host "ERROR: Unknown return value from image export SQL procedure. Exiting process."
        Return $false
    }
}


function NeedImageExport {
    param (
        [string]    $imageFilePath
    )

    # Tests the image file path to see if we need to export a new image. If no image file is present, 
    # returns TRUE. If image is out-of-date, returns TRUE. 

    if (Test-Path $imageFilePath) {
        $fileLastEditDays = ([datetime]::Now - (get-item $imageFilePath).LastWriteTime).Days
        Write-Host "File was last modified $fileLastEditDays days ago."
        if($fileLastEditDays -GE $SCRIPT:imageLifetimeDays) {
            Write-Host "File lifetime has expired."
            return $true
        } else {
            Write-Host "File is still current. Nothing to do."
            return $false
        }    
    } else {
        Write-Host "No image file currently exists for this user."
        return $true
    }
}


function GetGeneralAccessUserCode {
    Param (
        [int] $userId 
    )

    $generalAccessUserCode = (invoke-sqlcmd `
            -server synergy `
            -query ('select woodcroft.ufGetGeneralAccessUserCode({0})' -f $userId)
        ).Column1

    return $generalAccessUserCode
}


function PhotoSyncUser {
    param (
        [int] $ID
    )

    Write-Host "Starting image sync for user with ID $ID."
   
    # Image sync to folder which is used by multiple applications. 

    Write-Host "Syncing general purpose Images folder..."
    $imageFileName = "$ID.$SCRIPT:imageFileExtension"
    $imageFilePath = "$SCRIPT:synergyImagesFolder\$imageFileName"
    if(NeedImageExport -imageFilePath $imageFilePath) {
        $exportResult = ExportPhotoFromSynergy `
            -ID $ID `
            -fileName $imageFileName `
            -outputFolder $SCRIPT:synergyImagesFolder `
            -thumbnail $true

        if ($exportResult -EQ $true) {
            Write-Host "New image exported successfully."
        } else {
            Write-Host "Could not export photo for this user."
        }
    }

    # Image sync with General Access folder. Staff images should be saved using their 
    # SchoolStaffCode as the filename (e.g. SELBBE.jpg), whereas students should be saved using 
    # their Synergy ID as the filename (same as above).

    Write-Host "Syncing General Access Images folder..."
    $generalAccessUserCode = GetGeneralAccessUserCode -UserId $ID
    $imageFileName = "$generalAccessUserCode.$SCRIPT:imageFileExtension" 
    $imageFilePath = "$SCRIPT:generalAccessFolder\$imageFileName"
    
    if(NeedImageExport -imageFilePath $imageFilePath) {

        # Output to TEMP folder then scale down to around 160w x 190h for GA. 
        $exportResult = ExportPhotoFromSynergy `
            -ID $ID `
            -fileName $imageFileName `
            -outputFolder $ENV:TEMP `
            -thumbnail $false

        if ($exportResult -EQ $true) {

            Write-Host ("New image exported with user code = {0}." -f $generalAccessUserCode)

            $returnValue = C:\Powershell\scale.bat `
                -source "$ENV:TEMP\$imageFileName" `
                -target "$imageFilePath" `
                -max-height 200 `
                -keep-ratio yes

            Write-Host ("New image resized and moved to GA folder [{0}]." -f $imageFilePath)

            # TODO: Modify scale.bat so it returns success/fail value? 
        }        
    }

    Write-Host "Finished for ID $ID."
    Write-Host "---------------------------------------------------------------------------------------------------`n"    
}


####################################################################################################################
# MAIN
####################################################################################################################


Write-Host "Started at $(Get-Date -format 'yyyy.MM.dd HH:mm:ss').`n`n" *>> $logFilePath

$staffAndStudentsList = Invoke-Sqlcmd -server SYNERGY -query 'exec woodcroft.uspsGetAllStaffAndStudentsInfo'

foreach($id in $staffAndStudentsList.ID) {
    PhotoSyncUser -id $id *>> $logFilePath
}

# if ($createLibraryZip -EQ 'Y') {
#     Write-Host "$(Get-Date -format 'yyyy.MM.dd HH:mm:ss'): Creating ZIP file on Library drive for Oliver import." *>> $logFilePath
#     Compress-Archive `
#         -Path "$script:synergyImagesFolder/*" `
#         -DestinationPath "$libraryZipFile" `
#         -Update
# }


Write-Host "Finished at $(Get-Date -format 'yyyy.MM.dd HH:mm:ss')." *>> $logFilePath
Write-Host "==============================================================================" *>> $logFilePath
Write-Host "==============================================================================`n`n" *>> $logFilePath
