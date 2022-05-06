
# Support Functions
# Based on the development work found at 
# https://www.lewisroberts.com/2015/01/18/powershell-image-resize-function/
#
# Parameters
# $ImagePath          -> Originale Image to be resized
# $Quality            -> Image quality of the resized image
# $cutDownRatioPerc   -> Ratio to be reduced as a percentage. 50% means both width and height will be reduced by half.
# $OutputLocation     -> The file location (in format of folder\file_name) where the resized image should be stored
#

# Variables
$directory = "C:\images"    # Define the folder having the files to be resized
$moveDir = "C:\tempimages"  # Define the folder to be used to store resized images
$filesize = 300kb           # Define the minimum size of the files which needs to be resized (300 KB)
$originalFileName = ""      # A variable to hold the curerntly processing file name
$resizedFileName = ""       # A variable to hold the curerntly processing resized file name
$quality = 90               # Image quality of the resized image
$cutDownRatioPerc = 50      # Ratio to be reduced as a percentage. 50% means both width and height will be reduced by half.
$numberOfDays = 1          # Define how many number of days old
$logfile = "C:\logs\ImageResizing.log" # Define the log file path 
Function ResizeImage() {
    param([String]$ImagePath, [Int]$Quality = 90, [Int]$cutDownRatioPerc, [String]$OutputLocation)
 
    Add-Type -AssemblyName "System.Drawing"
 
    $img = [System.Drawing.Image]::FromFile($ImagePath)
 
    #Encoder parameter for image quality
    $ImageEncoder = [System.Drawing.Imaging.Encoder]::Quality
    $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($ImageEncoder, $Quality)
 
    # get codec
    $Codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
 
    #compute the final ratio to use
    $ratioX = ($cutDownRatioPerc / 100)
    $ratioY = ($cutDownRatioPerc / 100)
 
    $ratio = $ratioY
    if ($ratioX -le $ratioY) {
        $ratio = $ratioX
    }
 
    $newWidth = [int] ($img.Width * $ratio)
    $newHeight = [int] ($img.Height * $ratio)
 
    $bmpResized = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
    $graph = [System.Drawing.Graphics]::FromImage($bmpResized)
    $graph.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 
    $graph.Clear([System.Drawing.Color]::White)
    $graph.DrawImage($img, 0, 0, $newWidth, $newHeight)
 
    #save to file
    $bmpResized.Save($OutputLocation, $Codec, $($encoderParams))
    $bmpResized.Dispose()
    $img.Dispose()
}

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory = $True)]
        [string]
        $Message
    )

    if (-not(Test-Path -Path $logfile -PathType Leaf)) {
        try {
            $null = New-Item -ItemType File -Path $logfile -Force -ErrorAction Stop
            Write-Host "The file [$logfile] has been created."
        }
        catch {
            throw $_.Exception.Message
        }
    }

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "[$Stamp] [$Level] : $Message"
    If ($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}



# Actions
Get-ChildItem $directory -include *file -Recurse |
Where-Object { $_.Length -gt $filesize -and $_.CreationTime -lt (Get-Date).AddDays(-$numberOfDays) } |
ForEach-Object { 
    $originalFileName = ($_.FullName)
    $resizedFileName = ($moveDir + "\resized_" + $_.Name)
    Write-Log "INFO" "Read file: $originalFileName"
    ResizeImage $_.FullName $quality $cutDownRatioPerc $resizedFileName
    Write-Log "INFO" "$($_.Name) Image Resized"
    
    # Check backup file before delete the original
    if (Test-Path $resizedFileName -PathType Leaf) {
        Write-Log "INFO" "Removing Original file: $originalFileName"
        Remove-Item $originalFileName
        Write-Log "INFO" "Moving Resized file to: $originalFileName from: $resizedFileName"
        Copy-Item $resizedFileName $originalFileName
        if (-not (Test-Path $originalFileName -PathType Leaf)) {
            break
            throw "Unable to find original"
        }
        else {
            Remove-Item $resizedFileName
            Write-Log "INFO" "Resize finished: $originalFileName"
        }
    }
    else {
        Write-Log "ERROR" "Unable to locate backup file: $resizedFileName"
        Write-Log "ERROR" "Resized operation is skiped: $originalFileName"
    }
    
    # Reset variables
    $originalFileName = ""
    $resizedFileName = ""
}

