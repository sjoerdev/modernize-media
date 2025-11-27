# output
$InputFormats = "formats_images.txt";
$OutputFormat = "avif"
$Identifier = "magick"

function Run-Command($inputFilePath, $outputFilePath)
{
    magick $inputFilePath $outputFilePath
}

# input and output directories
$InputNameNormalized = $args[0].TrimEnd('\','/').Replace('./','').Replace('.\','')
$InputRoot = "./" + $InputNameNormalized
$OutputRoot = $InputRoot + "_" + $OutputFormat + "_" + $Identifier

# formats to take as input
$FormatsFilePath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) $InputFormats;
$Includes = Get-Content $FormatsFilePath

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
    $outputFile = [System.IO.FileInfo]$(Join-Path -Path $OutputRoot -ChildPath ([System.IO.Path]::ChangeExtension($relativePath, ("." + $OutputFormat))))

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

    Write-Host "[$Counter/$TotalFiles] [$progressPercent%] [$Identifier] Converting $($inputFile.Name) to $($outputFile.Name)"

    Run-Command "$($inputFile.FullName)" "$($outputFile.FullName)"
}

Write-Host "Finished converting media"