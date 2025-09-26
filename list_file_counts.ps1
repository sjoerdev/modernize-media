$rootDir = "./wdmycloud_backup"

$extensions = 
@(
    # image formats
    "bmp", "emf", "emz", "gif", "ico", "jpeg", "jpg", "png",
    "orf", "raw", "svg", "tif", "tiff", "snag",

    # video formats
    "avi", "dvr-ms", "flv", "mkv", "mod", "moi", "mov",
    "mp4", "mpg", "mpeg", "mswmm", "swf", "vob", "wmv", "wrf"
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