# input and output directories
$InputRoot = ".\wdmycloud_media_gesorteerd"
$OutputRoot = ".\wdmycloud_media_converted"

# video formats
$VideoFormatsToConvert = @("mod", "mov", "mpg", "wmv") # ignoring the corrupted avi and vob formats
$VideoFormatsToConvertWithGPU = @("mod", "mpg", "wmv") # formats that work with cuda and nvenc
$VideoFormatToConvertTo = "mp4"

# image formats
$ImageFormatsToConvert = @("jpg", "bmp", "orf", "png", "tif")
$ImageFormatToConvertTo = "jpeg"

# other formats
$formatsToCopyButNotConvert = @("avi", "vob", "mp4", "jpeg")

# recursively find all media files
$AllFiles = @()

foreach ($ext in $VideoFormatsToConvert)
{
    $AllFiles += Get-ChildItem -Path $InputRoot -Recurse -Include ("*." + $ext) -File
}
foreach ($ext in $ImageFormatsToConvert)
{
    $AllFiles += Get-ChildItem -Path $InputRoot -Recurse -Include ("*." + $ext) -File
}
foreach ($ext in $formatsToCopyButNotConvert)
{
    $AllFiles += Get-ChildItem -Path $InputRoot -Recurse -Include ("*." + $ext) -File
}

$TotalFiles = $AllFiles.Count
$Counter = 0

foreach ($inputFile in $AllFiles)
{
    $Counter++
    $progressPercent = [math]::Round(($Counter / $TotalFiles) * 100, 1)

    # check if its an image or a video
    $isImage = $ImageFormatsToConvert -contains $inputFile.Extension.ToLower().TrimStart('.')
    if ($isImage) { $formatToConvertTo = $ImageFormatToConvertTo }
    else { $formatToConvertTo = $VideoFormatToConvertTo }

    # check if the file should be converted or just copied over
    $inputFileExtension = $inputFile.Extension.ToLower().TrimStart('.')
    $shouldConvert = $formatsToCopyButNotConvert -notcontains $inputFileExtension

    # calculate output path
    $absInputRoot = (Resolve-Path $InputRoot).Path
    $absFile = (Resolve-Path $inputFile.FullName).Path
    $relativePath = $absFile.Substring($absInputRoot.Length).TrimStart('\')

    if ($shouldConvert)
    {
        $outputFile = [System.IO.FileInfo]$(Join-Path -Path $OutputRoot -ChildPath ([System.IO.Path]::ChangeExtension($relativePath, ("." + $formatToConvertTo))))
    }
    else
    {
        $outputFile = [System.IO.FileInfo]$(Join-Path -Path $OutputRoot -ChildPath $relativePath)
    }

    # make sure output path exists
    $outputDir = Split-Path -Path $outputFile.FullName -Parent
    if (-not (Test-Path $outputDir))
    {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }

    # skip already existing files
    if (Test-Path $outputFile.FullName)
    {
        Write-Host "Skipping existing file: $($outputFile.FullName)"
        continue
    }

    if ($shouldConvert)
    {
        Write-Host "[$Counter/$TotalFiles] [$progressPercent%] Converting $($inputFile.Name) to $($outputFile.Name)"
        
        if ($isImage)
        {
            magick $inputFile.FullName $outputFile.FullName
        }
        else
        {
            if ($VideoFormatsToConvertWithGPU -contains $inputFile.Extension.ToLower().TrimStart('.'))
            {
                ffmpeg -hide_banner -loglevel error -hwaccel cuda -i $inputFile.FullName -c:v h264_nvenc -preset fast -c:a aac $outputFile.FullName
            }
            else
            {
                ffmpeg -hide_banner -loglevel error -i $inputFile.FullName -c:v libx264 -preset fast -c:a aac $outputFile.FullName
            }
        }
    }
    else
    {
        Write-Host "[$Counter/$TotalFiles] [$progressPercent%] Copying $($inputFile.Name)"
        Copy-Item $inputFile.FullName $outputFile.FullName
    }
}

Write-Host "Finished converting media"