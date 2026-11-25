$InputNameNormalized = $args[0].TrimEnd('\','/').Replace('./','').Replace('.\','')
$rootDir = "./" + $InputNameNormalized

$mediaFiles = Get-ChildItem -Path $rootDir -Recurse -File
$grandTotal = $mediaFiles.Count
Write-Host "Total files: $grandTotal"