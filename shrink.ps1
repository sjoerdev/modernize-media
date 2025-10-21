# input and output directories
$InputRoot = "./" + $args[0]
$OutputRoot = $InputRoot

# video formats
$VideoFormatsToConvert = @("mp4")
$VideoFormatToConvertTo = "mkv"

# codecs and quality
$VideoCodecGPU = "av1_nvenc"
$VideoCodecPresetGPU = "p3"
$VideoCodecCPU = "libsvtav1"
$VideoCodecPresetCPU = "5"

# wether to use gpu or cpu
$Acceleration = $false
if ($Acceleration)
{
    $OutputRoot += "_" + $VideoCodecGPU
}
else
{
    $OutputRoot += "_" + $VideoCodecCPU
}

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

    if ($Acceleration)
    {
        Write-Host "[$Counter/$TotalFiles] [$progressPercent%] [GPU] Converting $($inputFile.Name) to $($outputFile.Name)"

        ffmpeg -hide_banner -loglevel error -hwaccel cuda -hwaccel_output_format cuda -i "$($inputFile.FullName)" -c:v $VideoCodecGPU -preset $VideoCodecPresetGPU -c:a copy "$($outputFile.FullName)"
    }
    else
    {
        Write-Host "[$Counter/$TotalFiles] [$progressPercent%] [CPU] Converting $($inputFile.Name) to $($outputFile.Name)"

        $env:SVT_LOG = 0
        ffmpeg -hide_banner -loglevel error -i "$($inputFile.FullName)" -c:v $VideoCodecCPU -preset $VideoCodecPresetCPU -c:a copy "$($outputFile.FullName)"
    }
}

Write-Host "Finished converting media"