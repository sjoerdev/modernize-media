$rootDir = "./" + $args[0]
$flatDir = $rootDir + "_flattened"

# only copy over files of these formats to the flat directory
$extensions = 
@(
    # image formats
    "bmp", "jpeg", "jpg", "png", "orf", "tif", "tiff",

    # video formats
    "avi", "mkv", "mod", "mov", "mp4", "mpg", "mpeg", "vob", "wmv"
)

if (-not (Test-Path $flatDir))
{
    New-Item -Path $flatDir -ItemType Directory | Out-Null
}

Write-Host "Flattening folder: $rootDir"

$files = Get-ChildItem -Path $rootDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $extensions -contains $_.Extension.TrimStart(".").ToLower() }
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
    Copy-Item -Path $file.FullName -Destination $destination -Force -ErrorAction SilentlyContinue
}

Write-Host "Flattening complete!"