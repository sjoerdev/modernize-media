$InputNameNormalized = $args[0].TrimEnd('\','/').Replace('./','').Replace('.\','')
$rootDir = "./" + $InputNameNormalized

$VideoFormatsFile = "formats_videos.txt";
$ImageFormatsFile = "formats_images.txt";
$VideoFormatsFilePath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) $VideoFormatsFile;
$ImageFormatsFilePath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) $ImageFormatsFile;
$Includes = (Get-Content $ImageFormatsFilePath) + (Get-Content $VideoFormatsFilePath)

$mediaFiles = Get-ChildItem -Path $rootDir -Recurse -File | Where-Object { $Includes -contains $_.Extension.TrimStart(".").ToLower() }

$groupedResults = $mediaFiles | Group-Object -Property { $_.Extension.TrimStart(".").ToLower() } | Sort-Object Count -Descending

$grandTotal = $mediaFiles.Count
Write-Host "Total of media files: $grandTotal"

foreach ($group in $groupedResults)
{
    $countStr = $group.name.ToString().PadLeft(10)
    Write-Host "$countStr | $($group.count.ToString().PadRight(10))"
}