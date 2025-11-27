# formats to take as imput
$FormatsFile = "formats_images.txt";
$FormatsFilePath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) $FormatsFile;
$Includes = Get-Content $FormatsFilePath

# output
$Format = "avif"

# input and output directories
$InputRoot = "./" + $args[0]
$OutputRoot = $InputRoot + "_" + "magick" + "_" + $Format

# recursively find all media files
$AllFiles = Get-ChildItem -Path $InputRoot -Recurse -File | Where-Object { $Includes -contains $_.Extension.TrimStart(".").ToLower() }

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
    $outputFile = [System.IO.FileInfo]$(Join-Path -Path $OutputRoot -ChildPath ([System.IO.Path]::ChangeExtension($relativePath, ("." + $Format))))

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

    Write-Host "[$Counter/$TotalFiles] [$progressPercent%] [magick] Converting $($inputFile.Name) to $($outputFile.Name)"

    magick "$($inputFile.FullName)" "$($outputFile.FullName)"
}

Write-Host "Finished converting media"