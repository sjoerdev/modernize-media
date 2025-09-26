$rootDir = "./wdmycloud_backup"

$extensions = 
@(
    # image formats
    "bmp", "jpeg", "jpg", "png", "orf", "tif", "tiff",

    # video formats
    "avi", "mkv", "mod", "mov", "mp4", "mpg", "mpeg", "vob", "wmv"
)

$mediaFiles = Get-ChildItem -Path $rootDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $extensions -contains $_.Extension.TrimStart(".").ToLower() }

$groupedResults = $mediaFiles | Group-Object -Property { $_.Extension.TrimStart(".").ToLower() } | Sort-Object Count -Descending

$grandTotal = $mediaFiles.Count
Write-Host "Total of media files: $grandTotal"

foreach ($group in $groupedResults)
{
    $countStr = $group.name.ToString().PadLeft(10)
    Write-Host "$countStr | $($group.count.ToString().PadRight(10))"
}