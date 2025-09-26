$rootDir = "./wdmycloud_backup"
$flatDir = "./wdmycloud_backup_flat"

Write-Host "Flattening folder: $rootDir"

$files = Get-ChildItem -Path $rootDir -Recurse -File

foreach ($file in $files)
{
    $destination = Join-Path -Path $rootDir -ChildPath $file.Name
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $extension = $file.Extension
    $counter = 1

    # rename if file exists
    while (Test-Path $destination)
    {
        $newName = "{0}_{1}{2}" -f $baseName, $counter, $extension
        $destination = Join-Path -Path $rootDir -ChildPath $newName
        $counter++
    }

    # move the file
    Move-Item -Path $file.FullName -Destination $destination
}

Write-Host "Flattening complete!"