param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path
)

$pathNormalized = $Path.TrimEnd('\', '/').Replace('./', '').Replace('.\', '')
$rootDir = Join-Path (Get-Location) $pathNormalized

if (-not (Test-Path -LiteralPath $rootDir -PathType Container)) {
    Write-Error "Directory not found: $rootDir"
    exit 1
}

$allFiles = @(Get-ChildItem -LiteralPath $rootDir -Recurse -File -Force)

$allTypes = $allFiles |
    Group-Object -Property { $_.Extension.TrimStart('.').ToLower() } |
    Sort-Object Name

$mediaTypesFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\formats\formats_videos.txt'
$imageTypesFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\formats\formats_images.txt'
$mediaExtensions = @(
    Get-Content -LiteralPath $mediaTypesFile
    Get-Content -LiteralPath $imageTypesFile
) | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ } | Select-Object -Unique

$mediaFiles = @($allFiles | Where-Object {
    $mediaExtensions -contains $_.Extension.TrimStart('.').ToLower()
})

$mediaTypes = $mediaFiles |
    Group-Object -Property { $_.Extension.TrimStart('.').ToLower() } |
    Sort-Object @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false }

$emptyDirectories = @(
    Get-ChildItem -LiteralPath $rootDir -Recurse -Directory -Force |
        Where-Object { @(Get-ChildItem -LiteralPath $_.FullName -Force).Count -eq 0 }
)

Write-Host "Total files: $($allFiles.Count)"
Write-Host ""
Write-Host "  Extension     Count"
Write-Host "  ----------    -----"

foreach ($group in $allTypes) {
    $extension = if ($group.Name) { ".$($group.Name)" } else { "(none)" }
    Write-Host ("  {0,-12} {1,5}" -f $extension, $group.Count)
}

Write-Host ""
Write-Host "Media files: $($mediaFiles.Count)"
Write-Host ""
Write-Host "  Extension     Count"
Write-Host "  ----------    -----"

foreach ($group in $mediaTypes) {
    Write-Host ("  {0,-12} {1,5}" -f $group.Name, $group.Count)
}

Write-Host ""
Write-Host "Empty directories: $($emptyDirectories.Count)"
