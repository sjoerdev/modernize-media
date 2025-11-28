$rootDir = "./" + $args[0]
$flatDir = $rootDir + "_flattened"

# only copy over files of these formats to the flat directory
$VideoFormatsFile = "formats_videos.txt";
$ImageFormatsFile = "formats_images.txt";
$VideoFormatsFilePath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) $VideoFormatsFile;
$ImageFormatsFilePath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) $ImageFormatsFile;
$Includes = (Get-Content $ImageFormatsFilePath) + (Get-Content $VideoFormatsFilePath)

if (-not (Test-Path $flatDir))
{
    New-Item -Path $flatDir -ItemType Directory | Out-Null
}

Write-Host "Flattening folder: $rootDir"

$files = Get-ChildItem -Path $rootDir -Recurse -File | Where-Object { $Includes -contains $_.Extension.TrimStart(".").ToLower() }
$filesTotal = $files.Count
$fileIndex = 0

foreach ($file in $files)
{
    $fileIndex++

    $progressPercent = [math]::Round(($fileIndex / $filesTotal) * 100, 1)
    Write-Host [$fileIndex/$filesTotal] [$progressPercent%] $file.Name

    $destination = Join-Path -Path $flatDir -ChildPath $file.Name
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $extension = $file.Extension
    $counter = 1

    # rename if file exists
    while (Test-Path $destination)
    {
        $newName = "{0}_{1}{2}" -f $baseName, $counter, $extension
        $destination = Join-Path -Path $flatDir -ChildPath $newName
        $counter++
    }

    # copy the file
    Copy-Item -Path $file.FullName -Destination $destination -Force
}

Write-Host "Flattening complete!"