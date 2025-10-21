# input and output directories
$InputRoot = "./" + $args[0]
$OutputRoot = $InputRoot + "_av1"

# video formats
$VideoFormatsToConvert = @("mp4")
$VideoFormatToConvertTo = "mkv"

$Acceleration = $true

# recursively find all media files
$AllFiles = @()

foreach ($ext in $VideoFormatsToConvert)
{
    $AllFiles += Get-ChildItem -Path $InputRoot -Recurse -Include ("*." + $ext) -File
}

$TotalFiles = $AllFiles.Count
$Counter = 0

foreach ($inputFile in $AllFiles)
{
    $Counter++
    $progressPercent = [math]::Round(($Counter / $TotalFiles) * 100, 1)

    # calculate output path
    $absInputRoot = (Resolve-Path $InputRoot).Path
    $absFile = (Resolve-Path $inputFile.FullName).Path
    $relativePath = $absFile.Substring($absInputRoot.Length).TrimStart('\')

    $outputFile = [System.IO.FileInfo]$(Join-Path -Path $OutputRoot -ChildPath ([System.IO.Path]::ChangeExtension($relativePath, ("." + $VideoFormatToConvertTo))))

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

    Write-Host "[$Counter/$TotalFiles] [$progressPercent%] Converting $($inputFile.Name) to $($outputFile.Name)"

    if ($Acceleration)
    {
        ffmpeg -hide_banner -loglevel error -hwaccel cuda -hwaccel_output_format cuda -i "$($inputFile.FullName)" -c:v av1_nvenc -preset fast -c:a copy "$($outputFile.FullName)"
    }
    else
    {
        $env:SVT_LOG = 0
        ffmpeg -hide_banner -loglevel error -i "$($inputFile.FullName)" -c:v libsvtav1 -preset 6 -c:a copy "$($outputFile.FullName)"
    }
}

Write-Host "Finished converting media"