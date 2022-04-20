# Variables
$directory = "C:\images"    # Define the folder having the files to be resized
$moveDir = "C:\tempimages"      # Define the folder to be used to store resized images
$filesize = 200kb                 # Define the minimum size of the files which needs to be resized (200 KB)
$currentFileName = ""                  # A variable to hold the curerntly processing file name
$currentResizedFileName = ""           # A variable to hold the curerntly processing resized file name

# Actions
Get-ChildItem $directory -include *file -Recurse |
Where-Object { $_.Length -gt $filesize } |
ForEach-Object { 
    $currentFileName = ($_.FullName)
    $currentResizedFileName = ($moveDir + "\resized_" + $_.Name)
    ResizeImage $_.FullName 90 50 $currentResizedFileName
    Remove-Item $currentFileName
    Move-Item $currentResizedFileName $currentFileName
    # Rename-Item $currentResizedFileName -NewName $_.Name 
    $currentFileName = ""
    $currentResizedFileName = ""
}

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
Function ResizeImage() {
    param([String]$ImagePath, [Int]$Quality = 90, [Int]$cutDownRatioPerc, [String]$OutputLocation)
 
    Add-Type -AssemblyName "System.Drawing"
 
    $img = [System.Drawing.Image]::FromFile($ImagePath)
 
    #Encoder parameter for image quality
    $ImageEncoder = [System.Drawing.Imaging.Encoder]::Quality
    $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($ImageEncoder, $Quality)
 
    # get codec
    $Codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where { $_.MimeType -eq 'image/jpeg' }
 
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